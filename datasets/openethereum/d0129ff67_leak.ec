commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
commit d0129ff67b5e69436df88a6758e81d880e924a23
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Feb 29 21:15:39 2016 +0100

    Fixed cache memory leak

diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index f30a674e6..23e9aaac9 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -465,6 +465,7 @@ impl BlockChain {
 			let mut write_details = self.block_details.write().unwrap();
 			for (hash, details) in update.block_details.into_iter() {
 				batch.put_extras(&hash, &details);
+				self.note_used(CacheID::Extras(ExtrasIndex::BlockDetails, hash.clone()));
 				write_details.insert(hash, details);
 			}
 		}
@@ -769,6 +770,14 @@ impl BlockChain {
 
 				// TODO: handle block_hashes properly.
 				block_hashes.clear();
+
+				blocks.shrink_to_fit();
+				block_details.shrink_to_fit();
+				block_hashes.shrink_to_fit();
+				transaction_addresses.shrink_to_fit();
+				block_logs.shrink_to_fit();
+				blocks_blooms.shrink_to_fit();
+				block_receipts.shrink_to_fit();
 			}
 			if self.cache_size().total() < self.max_cache_size.load(AtomicOrder::Relaxed) { break; }
 		}
