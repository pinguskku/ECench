commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
commit 03674af77969206efbb7cd009e84e02cb2c9dabc
Author: OneEvil <oneevil@bk.ru>
Date:   Fri Nov 6 16:01:26 2020 +0500

    Fix unnecessary conversion warnings

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index d1ba790f0..2593e29e4 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -320,11 +320,11 @@ func generateDataset(dest []uint32, epoch uint64, epochLength uint64, cache []ui
 			keccak512 := makeHasher(sha3.NewLegacyKeccak512())
 
 			// Calculate the data segment this thread should generate
-			batch := uint64((size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads)))
+			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
 			first := uint64(id) * batch
 			limit := first + batch
-			if limit > uint64(size/hashBytes) {
-				limit = uint64(size / hashBytes)
+			if limit > size/hashBytes {
+				limit = size / hashBytes
 			}
 			// Calculate the dataset segment
 			percent := uint32(size / hashBytes / 100)
