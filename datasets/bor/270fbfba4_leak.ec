commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
commit 270fbfba4bb4e0fe91ad2bb3a64cd4aa34da4c5f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 2d2260346..b4ce9237a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -155,9 +155,9 @@ func (p *peer) broadcastBlocks() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) broadcastTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to broadcast as full transactions
-		done  chan struct{}      // Non-nil if background broadcaster is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to broadcast as full transactions
+		done  chan struct{}         // Non-nil if background broadcaster is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight broadcast running, check if a new one is needed
@@ -217,9 +217,9 @@ func (p *peer) broadcastTransactions() {
 // node internals and at the same time rate limits queued data.
 func (p *peer) announceTransactions() {
 	var (
-		queue []common.Hash      // Queue of hashes to announce as transaction stubs
-		done  chan struct{}      // Non-nil if background announcer is running
-		fail  = make(chan error) // Channel used to receive network error
+		queue []common.Hash         // Queue of hashes to announce as transaction stubs
+		done  chan struct{}         // Non-nil if background announcer is running
+		fail  = make(chan error, 1) // Channel used to receive network error
 	)
 	for {
 		// If there's no in-flight announce running, check if a new one is needed
