commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
commit 9083923f2780599db03bdc595bf50100c61ebdc7
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Aug 26 18:34:16 2017 +0200

    optimized memorydb insert, remove and emplace

diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc8d0a3de..fcfde9695 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -181,7 +181,10 @@ impl HashDB for MemoryDB {
 	}
 
 	fn keys(&self) -> HashMap<H256, i32> {
-		self.data.iter().filter_map(|(k, v)| if v.1 != 0 {Some((k.clone(), v.1))} else {None}).collect()
+		self.data.iter()
+			.filter(|&(_, v)| v.1 != 0)
+			.map(|(k, v)| (*k, v.1))
+			.collect()
 	}
 
 	fn contains(&self, key: &H256) -> bool {
@@ -200,16 +203,17 @@ impl HashDB for MemoryDB {
 			return SHA3_NULL_RLP.clone();
 		}
 		let key = value.sha3();
-		if match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = DBValue::from_slice(value);
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = DBValue::from_slice(value);
+				}
 				*rc += 1;
-				false
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; false } ,
-			None => true,
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::from_slice(value), 1));
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::from_slice(value), 1));
+			},
 		}
 		key
 	}
@@ -219,17 +223,18 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		match self.data.get_mut(&key) {
-			Some(&mut (ref mut old_value, ref mut rc @ -0x80000000i32 ... 0)) => {
-				*old_value = value;
+		match self.data.entry(key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+				if *rc >= -0x80000000i32 && *rc <= 0 {
+					*old_value = value;
+				}
 				*rc += 1;
-				return;
 			},
-			Some(&mut (_, ref mut x)) => { *x += 1; return; } ,
-			None => {},
+			Entry::Vacant(entry) => {
+				entry.insert((value, 1));
+			},
 		}
-		// ... None falls through into...
-		self.data.insert(key, (value, 1));
 	}
 
 	fn remove(&mut self, key: &H256) {
@@ -237,11 +242,14 @@ impl HashDB for MemoryDB {
 			return;
 		}
 
-		if match self.data.get_mut(key) {
-			Some(&mut (_, ref mut x)) => { *x -= 1; false }
-			None => true
-		}{	// ... None falls through into...
-			self.data.insert(key.clone(), (DBValue::new(), -1));
+		match self.data.entry(*key) {
+			Entry::Occupied(mut entry) => {
+				let &mut (_, ref mut rc) = entry.get_mut();
+				*rc -= 1;
+			},
+			Entry::Vacant(entry) => {
+				entry.insert((DBValue::new(), -1));
+			},
 		}
 	}
 }
