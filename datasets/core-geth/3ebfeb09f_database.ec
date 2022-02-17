commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
Author: AusIV <code@ausiv.com>
Date:   Fri Jun 19 02:51:37 2020 -0500

    core/rawdb: fix high memory usage in freezer (#21243)
    
    The ancients variable in the freezer is a list of hashes, which
    identifies all of the hashes to be frozen. The slice is being allocated
    with a capacity of `limit`, which is the number of the last block
    this batch will attempt to add to the freezer. That means we are
    allocating memory for all of the blocks in the freezer, not just
    the ones to be added.
    
    If instead we allocate `limit - f.frozen`, we will only allocate
    enough space for the blocks we're about to add to the freezer. On
    mainnet this reduces usage by about 320 MB.

diff --git a/core/rawdb/freezer.go b/core/rawdb/freezer.go
index 3d4dc680d..01ad281ac 100644
--- a/core/rawdb/freezer.go
+++ b/core/rawdb/freezer.go
@@ -311,7 +311,7 @@ func (f *freezer) freeze(db ethdb.KeyValueStore) {
 		var (
 			start    = time.Now()
 			first    = f.frozen
-			ancients = make([]common.Hash, 0, limit)
+			ancients = make([]common.Hash, 0, limit-f.frozen)
 		)
 		for f.frozen < limit {
 			// Retrieves all the components of the canonical block
