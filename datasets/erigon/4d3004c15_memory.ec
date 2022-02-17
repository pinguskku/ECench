commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
commit 4d3004c15254dd566ba916b32c14d7ffe4f28601
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Wed Jun 24 19:56:27 2020 +0000

    trie: reduce allocs in insertPreimage (#21261)

diff --git a/trie/database.go b/trie/database.go
index 26cde274c..fe9f33c3a 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -240,14 +240,15 @@ func (db *Database) InsertBlob(hash common.Hash, blob []byte) {
 }
 
 // insertPreimage writes a new trie node pre-image to the memory database if it's
-// yet unknown. The method will make a copy of the slice.
+// yet unknown. The method will NOT make a copy of the slice,
+// only use if the preimage will NOT be changed later on.
 //
 // Note, this method assumes that the database's lock is held!
 func (db *Database) insertPreimage(hash common.Hash, preimage []byte) {
 	if _, ok := db.preimages[hash]; ok {
 		return
 	}
-	db.preimages[hash] = common.CopyBytes(preimage)
+	db.preimages[hash] = preimage
 	db.preimagesSize += common.StorageSize(common.HashLength + len(preimage))
 }
 
