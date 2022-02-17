commit 2ad0e192cf934ad971d008a17eed3596f6a2b3d2
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Mar 13 23:47:15 2020 +0200

    eth: fix transaction announce/broadcast goroutine leak

diff --git a/eth/peer.go b/eth/peer.go
index 5c3ed436a..1a89a8aa2 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -156,9 +156,9 @@ func (p *peer) broadcastBlocks() {
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
@@ -218,9 +218,9 @@ func (p *peer) broadcastTransactions() {
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
