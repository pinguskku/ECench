commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
commit 6ddabc0f4903b07fe03bf4425a4e1140c5aca6f0
Author: Kirill Pimenov <kirill@pimenov.cc>
Date:   Tue Nov 14 13:06:50 2017 +0100

    Small performance gain in allocations
    
    As measured in
    https://gist.github.com/kirushik/e0d93759b0cd102f814408595c20a9d0,
    it's much faster not to iterate over zeroes, and just allocate a
    contiguous array of zeroes directly.

diff --git a/ethstore/src/account/crypto.rs b/ethstore/src/account/crypto.rs
index 7d87b1c69..cc7489514 100755
--- a/ethstore/src/account/crypto.rs
+++ b/ethstore/src/account/crypto.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use std::str;
 use ethkey::Secret;
 use {json, Error, crypto};
@@ -90,9 +89,7 @@ impl Crypto {
 		// preallocated (on-stack in case of `Secret`) buffer to hold cipher
 		// length = length(plain) as we are using CTR-approach
 		let plain_len = plain.len();
-		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::new();
-		ciphertext.grow(plain_len);
-		ciphertext.extend(repeat(0).take(plain_len));
+		let mut ciphertext: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; plain_len]);
 
 		// aes-128-ctr with initial vector of iv
 		crypto::aes::encrypt(&derived_left_bits, &iv, plain, &mut *ciphertext);
@@ -143,9 +140,7 @@ impl Crypto {
 			return Err(Error::InvalidPassword);
 		}
 
-		let mut plain: SmallVec<[u8; 32]> = SmallVec::new();
-		plain.grow(expected_len);
-		plain.extend(repeat(0).take(expected_len));
+		let mut plain: SmallVec<[u8; 32]> = SmallVec::from_vec(vec![0; expected_len]);
 
 		match self.cipher {
 			Cipher::Aes128Ctr(ref params) => {
diff --git a/rpc/src/v1/helpers/secretstore.rs b/rpc/src/v1/helpers/secretstore.rs
index b5528c778..39709e78e 100644
--- a/rpc/src/v1/helpers/secretstore.rs
+++ b/rpc/src/v1/helpers/secretstore.rs
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::iter::repeat;
 use rand::{Rng, OsRng};
 use ethkey::{Public, Secret, math};
 use crypto;
@@ -32,10 +31,13 @@ pub fn encrypt_document(key: Bytes, document: Bytes) -> Result<Bytes, Error> {
 
 	// use symmetric encryption to encrypt document
 	let iv = initialization_vector();
-	let mut encrypted_document = Vec::with_capacity(document.len() + iv.len());
-	encrypted_document.extend(repeat(0).take(document.len()));
-	crypto::aes::encrypt(&key, &iv, &document, &mut encrypted_document);
-	encrypted_document.extend_from_slice(&iv);
+	let mut encrypted_document = vec![0; document.len() + iv.len()];
+	{
+		let (mut encryption_buffer, iv_buffer) = encrypted_document.split_at_mut(document.len());
+
+		crypto::aes::encrypt(&key, &iv, &document, &mut encryption_buffer);
+		iv_buffer.copy_from_slice(&iv);
+	}
 
 	Ok(encrypted_document)
 }
@@ -53,8 +55,7 @@ pub fn decrypt_document(key: Bytes, mut encrypted_document: Bytes) -> Result<Byt
 
 	// use symmetric decryption to decrypt document
 	let iv = encrypted_document.split_off(encrypted_document_len - INIT_VEC_LEN);
-	let mut document = Vec::with_capacity(encrypted_document_len - INIT_VEC_LEN);
-	document.extend(repeat(0).take(encrypted_document_len - INIT_VEC_LEN));
+	let mut document = vec![0; encrypted_document_len - INIT_VEC_LEN];
 	crypto::aes::decrypt(&key, &iv, &encrypted_document, &mut document);
 
 	Ok(document)
