commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
-commit 0f4e7c9b0d570ff7f79b0765a0bd3737ce635e9a
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Mon Aug 24 10:32:12 2020 +0200
-
-    eth: utilize sync bloom for getNodeData (#21445)
-    
-    * eth/downloader, eth/handler: utilize sync bloom for getNodeData
-    
-    * trie: handle if bloom is nil
-    
-    * trie, downloader: check bloom nilness externally
-
-commit 1b5a867eec711d83abfda18f7083f0c64a50f8b2
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Sat Aug 22 18:12:04 2020 +0200
-
-    core: do less lookups when writing fast-sync block bodies (#21468)
-
-commit 87c0ba92136a75db0ab2aba1046d4a9860375d6a
-Author: Gary Rong <garyrong0905@gmail.com>
-Date:   Fri Aug 21 20:10:40 2020 +0800
-
-    core, eth, les, trie: add a prefix to contract code (#21080)
-
-commit b68929caee777e22f8c6e1bbae0e8c91f5d4cfe5
-Merge: 4e54b1a45 9f7b79af0
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Aug 21 14:43:14 2020 +0300
-
-    Merge pull request #21472 from holiman/fix_dltest_fail
-    
-    eth/downloader: fix rollback issue on short chains
-
-commit 9f7b79af00a1ed57ab8640636041a81b58ecff59
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Fri Aug 21 13:27:10 2020 +0200
-
-    eth/downloader: fix rollback issue on short chains
-
-commit 4e54b1a45ead09c1f4ab85ba7f62accd8f672b12
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Fri Aug 21 10:04:36 2020 +0200
-
-    metrics: zero temp variable in  updateMeter (#21470)
-    
-    * metrics: zero temp variable in  updateMeter
-    
-    Previously the temp variable was not updated properly after summing it to count.
-    This meant we had astronomically high metrics, now we zero out the temp whenever we
-    sum it onto the snapshot count
-    
-    * metrics: move temp variable to be aligned, unit tests
-    
-    Moves the temp variable in MeterSnapshot to be 64-bit aligned because of the atomic bug.
-    Adds a unit test, that catches the previous bug.
-
-commit a70a79b285d9176505c5bbf73e691ed142759367
-Merge: 8cbdc8638 15fdaf200
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 17:41:26 2020 +0300
-
-    Merge pull request #21466 from karalabe/go1.15
-    
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 15fdaf20055323874a05bcae780014fb99e7cffd
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 16:41:37 2020 +0300
-
-    travis, dockerfile, appveyor, build: bump to Go 1.15
-
-commit 8cbdc8638fd28693f84d7bdbbdd587e8c57f6383
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Thu Aug 20 13:01:24 2020 +0300
-
-    core: define and test chain rewind corner cases (#21409)
-    
-    * core: define and test chain reparation cornercases
-    
-    * core: write up a variety of set-head tests
-    
-    * core, eth: unify chain rollbacks, handle all the cases
-    
-    * core: make linter smile
-    
-    * core: remove commented out legacy code
-    
-    * core, eth/downloader: fix review comments
-    
-    * core: revert a removed recovery mechanism
