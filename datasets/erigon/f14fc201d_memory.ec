commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
commit f14fc201dc0be49375531bb3d513b7ac542b20a4
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
    # Conflicts:
    #       core/rawdb/freezer.go

diff --git a/to-merge.txt b/to-merge.txt
index 5babf4aac..a6a9e8f8f 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -891,32 +891,3 @@ Date:   Fri Jun 19 15:43:52 2020 +0200
     * common/fdlimit: build on DragonflyBSD
     
     * review feedback
-
-commit 3ebfeb09fe86a14c5dd4929b481ac67f51b13569
-Author: AusIV <code@ausiv.com>
-Date:   Fri Jun 19 02:51:37 2020 -0500
-
-    core/rawdb: fix high memory usage in freezer (#21243)
-    
-    The ancients variable in the freezer is a list of hashes, which
-    identifies all of the hashes to be frozen. The slice is being allocated
-    with a capacity of `limit`, which is the number of the last block
-    this batch will attempt to add to the freezer. That means we are
-    allocating memory for all of the blocks in the freezer, not just
-    the ones to be added.
-    
-    If instead we allocate `limit - f.frozen`, we will only allocate
-    enough space for the blocks we're about to add to the freezer. On
-    mainnet this reduces usage by about 320 MB.
-
-commit 5435e0d1a1ae187f638ba3c852996713aa27d370
-Author: ucwong <ucwong@126.com>
-Date:   Thu Jun 18 23:58:49 2020 +0800
-
-    whisper : use timer.Ticker instead of sleep (#21240)
-    
-    * whisper : use timer.Ticker instead of sleep
-    
-    * lint: Fix linter error
-    
-    Co-authored-by: Guillaume Ballet <gballet@gmail.com>
