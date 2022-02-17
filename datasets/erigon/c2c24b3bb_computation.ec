commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
commit c2c24b3bb419a8ffffb58ec25788b951bef779f9
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 18:54:57 2015 +0200

    downloader: improved downloading and synchronisation
    
    * Downloader's peers keeps track of peer's previously requested hashes
      so that we don't have to re-request
    * Changed `AddBlock` to be fully synchronous

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 41484e927..810031c79 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -26,9 +26,12 @@ const (
 )
 
 var (
-	errLowTd       = errors.New("peer's TD is too low")
-	errBusy        = errors.New("busy")
-	errUnknownPeer = errors.New("peer's unknown or unhealthy")
+	errLowTd        = errors.New("peer's TD is too low")
+	errBusy         = errors.New("busy")
+	errUnknownPeer  = errors.New("peer's unknown or unhealthy")
+	errBadPeer      = errors.New("action from bad peer ignored")
+	errTimeout      = errors.New("timeout")
+	errEmptyHashSet = errors.New("empty hash set by peer")
 )
 
 type hashCheckFn func(common.Hash) bool
@@ -116,73 +119,6 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
-// checks fail an error will be returned. This method is synchronous
-func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
-	// Check if we're busy
-	if d.isBusy() {
-		return nil, errBusy
-	}
-
-	// Attempt to select a peer. This can either be nothing, which returns, best peer
-	// or selected peer. If no peer could be found an error will be returned
-	var p *peer
-	if len(id) == 0 {
-		p = d.peers[id]
-		if p == nil {
-			return nil, errUnknownPeer
-		}
-	} else {
-		p = d.peers.bestPeer()
-	}
-
-	// Make sure our td is lower than the peer's td
-	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
-		return nil, errLowTd
-	}
-
-	// Get the hash from the peer and initiate the downloading progress.
-	err := d.getFromPeer(p, p.recentHash, false)
-	if err != nil {
-		return nil, err
-	}
-
-	return d.queue.blocks, nil
-}
-
-// Synchronise will synchronise using the best peer.
-func (d *Downloader) Synchronise() (types.Blocks, error) {
-	return d.SynchroniseWithPeer("")
-}
-
-func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
-	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
-	// Start the fetcher. This will block the update entirely
-	// interupts need to be send to the appropriate channels
-	// respectively.
-	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
-		// handle error
-		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-		// XXX Reset
-		return err
-	}
-
-	// Start fetching blocks in paralel. The strategy is simple
-	// take any available peers, seserve a chunk for each peer available,
-	// let the peer deliver the chunkn and periodically check if a peer
-	// has timedout. When done downloading, process blocks.
-	if err := d.startFetchingBlocks(p); err != nil {
-		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-		// XXX reset
-		return err
-	}
-
-	glog.V(logger.Detail).Infoln("Sync completed")
-
-	return nil
-}
-
 func (d *Downloader) peerHandler() {
 	// itimer is used to determine when to start ignoring `minDesiredPeerCount`
 	itimer := time.NewTimer(peerCountTimeout)
@@ -236,34 +172,14 @@ out:
 	for {
 		select {
 		case sync := <-d.syncCh:
-			start := time.Now()
-
 			var peer *peer = sync.peer
-
 			d.activePeer = peer.id
-			glog.V(logger.Detail).Infoln("Synchronising with the network using:", peer.id)
-			// Start the fetcher. This will block the update entirely
-			// interupts need to be send to the appropriate channels
-			// respectively.
-			if err := d.startFetchingHashes(peer, sync.hash, sync.ignoreInitial); err != nil {
-				// handle error
-				glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
-				// XXX Reset
-				break
-			}
 
-			// Start fetching blocks in paralel. The strategy is simple
-			// take any available peers, seserve a chunk for each peer available,
-			// let the peer deliver the chunkn and periodically check if a peer
-			// has timedout. When done downloading, process blocks.
-			if err := d.startFetchingBlocks(peer); err != nil {
-				glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
-				// XXX reset
+			err := d.getFromPeer(peer, sync.hash, sync.ignoreInitial)
+			if err != nil {
 				break
 			}
 
-			glog.V(logger.Detail).Infoln("Network sync completed in", time.Since(start))
-
 			d.process()
 		case <-d.quit:
 			break out
@@ -314,9 +230,8 @@ out:
 				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", p.id)
 				d.queue.reset()
 
-				break out
+				return errEmptyHashSet
 			} else if !done { // Check if we're done fetching
-				//fmt.Println("re-fetch. current =", d.queue.hashPool.Size())
 				// Get the next set of hashes
 				p.getHashes(hashes[len(hashes)-1])
 			} else { // we're done
@@ -324,9 +239,12 @@ out:
 			}
 		case <-failureResponse.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
+			// TODO instead of reseting the queue select a new peer from which we can start downloading hashes.
+			// 1. check for peer's best hash to be included in the current hash set;
+			// 2. resume from last point (hashes[len(hashes)-1]) using the newly selected peer.
 			d.queue.reset()
 
-			break out
+			return errTimeout
 		}
 	}
 	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
@@ -367,7 +285,6 @@ out:
 						continue
 					}
 
-					//fmt.Println("fetching for", peer.id)
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
@@ -417,7 +334,6 @@ out:
 				}
 
 			}
-			//fmt.Println(d.queue.hashPool.Size(), len(d.queue.fetching))
 		}
 	}
 
@@ -441,11 +357,14 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 // Add an (unrequested) block to the downloader. This is usually done through the
 // NewBlockMsg by the protocol handler.
-func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
+// Adding blocks is done synchronously. if there are missing blocks, blocks will be
+// fetched first. If the downloader is busy or if some other processed failed an error
+// will be returned.
+func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) error {
 	hash := block.Hash()
 
 	if d.hasBlock(hash) {
-		return
+		return fmt.Errorf("known block %x", hash.Bytes()[:4])
 	}
 
 	peer := d.peers.getPeer(id)
@@ -453,7 +372,7 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	// and add the block. Otherwise just ignore it
 	if peer == nil {
 		glog.V(logger.Detail).Infof("Ignored block from bad peer %s\n", id)
-		return
+		return errBadPeer
 	}
 
 	peer.mu.Lock()
@@ -466,17 +385,24 @@ func (d *Downloader) AddBlock(id string, block *types.Block, td *big.Int) {
 	d.queue.addBlock(id, block, td)
 
 	// if neither go ahead to process
-	if !d.isBusy() {
-		// Check if the parent of the received block is known.
-		// If the block is not know, request it otherwise, request.
-		phash := block.ParentHash()
-		if !d.hasBlock(phash) {
-			glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
-			d.syncCh <- syncPack{peer, peer.recentHash, true}
-		} else {
-			d.process()
+	if d.isBusy() {
+		return errBusy
+	}
+
+	// Check if the parent of the received block is known.
+	// If the block is not know, request it otherwise, request.
+	phash := block.ParentHash()
+	if !d.hasBlock(phash) {
+		glog.V(logger.Detail).Infof("Missing parent %x, requires fetching\n", phash.Bytes()[:4])
+
+		// Get the missing hashes from the peer (synchronously)
+		err := d.getFromPeer(peer, peer.recentHash, true)
+		if err != nil {
+			return err
 		}
 	}
+
+	return d.process()
 }
 
 // Deliver a chunk to the downloader. This is usually done through the BlocksMsg by
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 4cd306a05..5d5208e8e 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -6,6 +6,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"gopkg.in/fatih/set.v0"
 )
 
 const (
@@ -64,13 +65,23 @@ type peer struct {
 	td         *big.Int
 	recentHash common.Hash
 
+	requested *set.Set
+
 	getHashes hashFetcherFn
 	getBlocks blockFetcherFn
 }
 
 // create a new peer
 func newPeer(id string, td *big.Int, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) *peer {
-	return &peer{id: id, td: td, recentHash: hash, getHashes: getHashes, getBlocks: getBlocks, state: idleState}
+	return &peer{
+		id:         id,
+		td:         td,
+		recentHash: hash,
+		getHashes:  getHashes,
+		getBlocks:  getBlocks,
+		state:      idleState,
+		requested:  set.New(),
+	}
 }
 
 // fetch a chunk using the peer
@@ -82,6 +93,8 @@ func (p *peer) fetch(chunk *chunk) error {
 		return errors.New("peer already fetching chunk")
 	}
 
+	p.requested.Merge(chunk.hashes)
+
 	// set working state
 	p.state = workingState
 	// convert the set to a fetchable slice
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index df3bf7087..5745bf1f8 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -65,6 +65,9 @@ func (c *queue) get(p *peer, max int) *chunk {
 
 		return true
 	})
+	// remove hashes that have previously been fetched
+	hashes.Separate(p.requested)
+
 	// remove the fetchable hashes from hash pool
 	c.hashPool.Separate(hashes)
 	c.fetchPool.Merge(hashes)
diff --git a/eth/downloader/synchronous.go b/eth/downloader/synchronous.go
new file mode 100644
index 000000000..0511533cf
--- /dev/null
+++ b/eth/downloader/synchronous.go
@@ -0,0 +1,77 @@
+package downloader
+
+import (
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/logger"
+	"github.com/ethereum/go-ethereum/logger/glog"
+)
+
+// THIS IS PENDING AND TO DO CHANGES FOR MAKING THE DOWNLOADER SYNCHRONOUS
+
+// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
+// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// checks fail an error will be returned. This method is synchronous
+func (d *Downloader) SynchroniseWithPeer(id string) (types.Blocks, error) {
+	// Check if we're busy
+	if d.isBusy() {
+		return nil, errBusy
+	}
+
+	// Attempt to select a peer. This can either be nothing, which returns, best peer
+	// or selected peer. If no peer could be found an error will be returned
+	var p *peer
+	if len(id) == 0 {
+		p = d.peers[id]
+		if p == nil {
+			return nil, errUnknownPeer
+		}
+	} else {
+		p = d.peers.bestPeer()
+	}
+
+	// Make sure our td is lower than the peer's td
+	if p.td.Cmp(d.currentTd()) <= 0 || d.hasBlock(p.recentHash) {
+		return nil, errLowTd
+	}
+
+	// Get the hash from the peer and initiate the downloading progress.
+	err := d.getFromPeer(p, p.recentHash, false)
+	if err != nil {
+		return nil, err
+	}
+
+	return d.queue.blocks, nil
+}
+
+// Synchronise will synchronise using the best peer.
+func (d *Downloader) Synchronise() (types.Blocks, error) {
+	return d.SynchroniseWithPeer("")
+}
+
+func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) error {
+	glog.V(logger.Detail).Infoln("Synchronising with the network using:", p.id)
+	// Start the fetcher. This will block the update entirely
+	// interupts need to be send to the appropriate channels
+	// respectively.
+	if err := d.startFetchingHashes(p, hash, ignoreInitial); err != nil {
+		// handle error
+		glog.V(logger.Debug).Infoln("Error fetching hashes:", err)
+		// XXX Reset
+		return err
+	}
+
+	// Start fetching blocks in paralel. The strategy is simple
+	// take any available peers, seserve a chunk for each peer available,
+	// let the peer deliver the chunkn and periodically check if a peer
+	// has timedout. When done downloading, process blocks.
+	if err := d.startFetchingBlocks(p); err != nil {
+		glog.V(logger.Debug).Infoln("Error downloading blocks:", err)
+		// XXX reset
+		return err
+	}
+
+	glog.V(logger.Detail).Infoln("Sync completed")
+
+	return nil
+}
