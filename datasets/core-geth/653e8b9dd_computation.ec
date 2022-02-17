commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
commit 653e8b9dd9b7a1565b0e26c71ad70a83803ad529
Author: jk-jeongkyun <45347815+jeongkyun-oh@users.noreply.github.com>
Date:   Mon Dec 28 06:26:42 2020 +0900

    eth/downloader: remove unnecessary condition (#22052)

diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 2150842f8..ac7edc2c6 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -893,9 +893,6 @@ func (q *queue) deliver(id string, taskPool map[common.Hash]*types.Header,
 		return accepted, nil
 	}
 	// If none of the data was good, it's a stale delivery
-	if errors.Is(failure, errInvalidChain) {
-		return accepted, failure
-	}
 	if accepted > 0 {
 		return accepted, fmt.Errorf("partial failure: %v", failure)
 	}
