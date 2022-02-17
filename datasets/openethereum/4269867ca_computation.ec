commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
commit 4269867ca422f96f8f0beeb1a8bed583de076a9f
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Mon Jul 11 19:56:27 2016 +0200

    remove unnecessary assertion

diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index 44b720422..aff16b86e 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -84,8 +84,6 @@ fn write_chunk(raw_data: &[u8], compression_buffer: &mut Vec<u8>, path: &Path) -
 	let compressed = &compression_buffer[..compressed_size];
 	let hash = compressed.sha3();
 
-	assert!(snappy::validate_compressed_buffer(compressed));
-
 	let mut file_path = path.to_owned();
 	file_path.push(hash.hex());
 
