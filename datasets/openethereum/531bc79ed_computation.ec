commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
commit 531bc79edcdf1820692b9c02ddaa382535758e04
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Aug 3 18:36:45 2016 +0200

    removed unused code from util and unnecessary dependency of FixedHash (#1824)

diff --git a/util/src/bytes.rs b/util/src/bytes.rs
index ef2156b1a..3c022e8bf 100644
--- a/util/src/bytes.rs
+++ b/util/src/bytes.rs
@@ -35,46 +35,8 @@
 use std::fmt;
 use std::slice;
 use std::ops::{Deref, DerefMut};
-use elastic_array::*;
 
-/// Vector like object
-pub trait VecLike<T> {
-	/// Add an element to the collection
-    fn vec_push(&mut self, value: T);
-
-	/// Add a slice to the collection
-    fn vec_extend(&mut self, slice: &[T]);
-}
-
-impl<T> VecLike<T> for Vec<T> where T: Copy {
-	fn vec_push(&mut self, value: T) {
-		Vec::<T>::push(self, value)
-	}
-
-	fn vec_extend(&mut self, slice: &[T]) {
-		Vec::<T>::extend_from_slice(self, slice)
-	}
-}
-
-macro_rules! impl_veclike_for_elastic_array {
-	($from: ident) => {
-		impl<T> VecLike<T> for $from<T> where T: Copy {
-			fn vec_push(&mut self, value: T) {
-				$from::<T>::push(self, value)
-			}
-			fn vec_extend(&mut self, slice: &[T]) {
-				$from::<T>::append_slice(self, slice)
-
-			}
-		}
-	}
-}
-
-impl_veclike_for_elastic_array!(ElasticArray16);
-impl_veclike_for_elastic_array!(ElasticArray32);
-impl_veclike_for_elastic_array!(ElasticArray1024);
-
-/// Slie pretty print helper
+/// Slice pretty print helper
 pub struct PrettySlice<'a> (&'a [u8]);
 
 impl<'a> fmt::Debug for PrettySlice<'a> {
diff --git a/util/src/rlp/bytes.rs b/util/src/rlp/bytes.rs
index 479fc7261..8d33f390d 100644
--- a/util/src/rlp/bytes.rs
+++ b/util/src/rlp/bytes.rs
@@ -22,7 +22,7 @@ use std::fmt;
 use std::cmp::Ordering;
 use std::error::Error as StdError;
 use bigint::uint::{Uint, U128, U256};
-use hash::FixedHash;
+use hash::{H64, H128, Address, H256, H512, H520, H2048};
 use elastic_array::*;
 
 /// Vector like object
@@ -146,13 +146,25 @@ macro_rules! impl_uint_to_bytes {
 impl_uint_to_bytes!(U256);
 impl_uint_to_bytes!(U128);
 
-impl <T>ToBytes for T where T: FixedHash {
-	fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
-		out.vec_extend(self.as_slice());
+macro_rules! impl_hash_to_bytes {
+	($name: ident) => {
+		impl ToBytes for $name {
+			fn to_bytes<V: VecLike<u8>>(&self, out: &mut V) {
+				out.vec_extend(&self);
+			}
+			fn to_bytes_len(&self) -> usize { self.len() }
+		}
 	}
-	fn to_bytes_len(&self) -> usize { self.as_slice().len() }
 }
 
+impl_hash_to_bytes!(H64);
+impl_hash_to_bytes!(H128);
+impl_hash_to_bytes!(Address);
+impl_hash_to_bytes!(H256);
+impl_hash_to_bytes!(H512);
+impl_hash_to_bytes!(H520);
+impl_hash_to_bytes!(H2048);
+
 /// Error returned when `FromBytes` conversation goes wrong
 #[derive(Debug, PartialEq, Eq)]
 pub enum FromBytesError {
@@ -250,15 +262,29 @@ macro_rules! impl_uint_from_bytes {
 impl_uint_from_bytes!(U256, 32);
 impl_uint_from_bytes!(U128, 16);
 
-impl <T>FromBytes for T where T: FixedHash {
-	fn from_bytes(bytes: &[u8]) -> FromBytesResult<T> {
-		match bytes.len().cmp(&T::len()) {
-			Ordering::Less => return Err(FromBytesError::DataIsTooShort),
-			Ordering::Greater => return Err(FromBytesError::DataIsTooLong),
-			Ordering::Equal => ()
-		};
-
-		Ok(T::from_slice(bytes))
+macro_rules! impl_hash_from_bytes {
+	($name: ident, $size: expr) => {
+		impl FromBytes for $name {
+			fn from_bytes(bytes: &[u8]) -> FromBytesResult<$name> {
+				match bytes.len().cmp(&$size) {
+					Ordering::Less => Err(FromBytesError::DataIsTooShort),
+					Ordering::Greater => Err(FromBytesError::DataIsTooLong),
+					Ordering::Equal => {
+						let mut t = [0u8; $size];
+						t.copy_from_slice(bytes);
+						Ok($name(t))
+					}
+				}
+			}
+		}
 	}
 }
 
+impl_hash_from_bytes!(H64, 8);
+impl_hash_from_bytes!(H128, 16);
+impl_hash_from_bytes!(Address, 20);
+impl_hash_from_bytes!(H256, 32);
+impl_hash_from_bytes!(H512, 64);
+impl_hash_from_bytes!(H520, 65);
+impl_hash_from_bytes!(H2048, 256);
+
