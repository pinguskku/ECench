commit 1020560af632d6359dcf44c43314dc2df78e2b5b
Author: Niklas Adolfsson <niklasadolfsson1@gmail.com>
Date:   Thu May 31 13:39:25 2018 +0200

    Remove a couple of unnecessary `transmute()` (#8736)

diff --git a/ethash/src/compute.rs b/ethash/src/compute.rs
index 48906b9ed..de2b57637 100644
--- a/ethash/src/compute.rs
+++ b/ethash/src/compute.rs
@@ -25,9 +25,8 @@ use seed_compute::SeedHashCompute;
 use shared::*;
 use std::io;
 
-use std::mem;
+use std::{mem, ptr};
 use std::path::Path;
-use std::ptr;
 
 const MIX_WORDS: usize = ETHASH_MIX_BYTES / 4;
 const MIX_NODES: usize = MIX_WORDS / NODE_WORDS;
@@ -111,7 +110,7 @@ pub fn quick_get_difficulty(header_hash: &H256, nonce: u64, mix_hash: &H256) ->
 		let mut buf: [u8; 64 + 32] = mem::uninitialized();
 
 		ptr::copy_nonoverlapping(header_hash.as_ptr(), buf.as_mut_ptr(), 32);
-		ptr::copy_nonoverlapping(mem::transmute(&nonce), buf[32..].as_mut_ptr(), 8);
+		ptr::copy_nonoverlapping(&nonce as *const u64 as *const u8, buf[32..].as_mut_ptr(), 8);
 
 		keccak_512::unchecked(buf.as_mut_ptr(), 64, buf.as_ptr(), 40);
 		ptr::copy_nonoverlapping(mix_hash.as_ptr(), buf[64..].as_mut_ptr(), 32);
diff --git a/util/plain_hasher/src/lib.rs b/util/plain_hasher/src/lib.rs
index 54bad92f4..d08d4dd1a 100644
--- a/util/plain_hasher/src/lib.rs
+++ b/util/plain_hasher/src/lib.rs
@@ -2,9 +2,9 @@
 extern crate crunchy;
 extern crate ethereum_types;
 
-use std::{hash, mem};
-use std::collections::{HashMap, HashSet};
 use ethereum_types::H256;
+use std::collections::{HashMap, HashSet};
+use std::hash;
 
 /// Specialized version of `HashMap` with H256 keys and fast hashing function.
 pub type H256FastMap<T> = HashMap<H256, T, hash::BuildHasherDefault<PlainHasher>>;
@@ -28,16 +28,13 @@ impl hash::Hasher for PlainHasher {
 	#[allow(unused_assignments)]
 	fn write(&mut self, bytes: &[u8]) {
 		debug_assert!(bytes.len() == 32);
+		let mut bytes_ptr = bytes.as_ptr();
+		let mut prefix_ptr = &mut self.prefix as *mut u64 as *mut u8;
 
-		unsafe {
-			let mut bytes_ptr = bytes.as_ptr();
-			let prefix_u8: &mut [u8; 8] = mem::transmute(&mut self.prefix);
-			let mut prefix_ptr = prefix_u8.as_mut_ptr();
-
-			unroll! {
-				for _i in 0..8 {
+		unroll! {
+			for _i in 0..8 {
+				unsafe { 
 					*prefix_ptr ^= (*bytes_ptr ^ *bytes_ptr.offset(8)) ^ (*bytes_ptr.offset(16) ^ *bytes_ptr.offset(24));
-
 					bytes_ptr = bytes_ptr.offset(1);
 					prefix_ptr = prefix_ptr.offset(1);
 				}
