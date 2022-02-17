commit ba2dfa5ce43d72733c864bc43f7b80b39c674733
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Wed Feb 20 14:45:25 2019 +0100

    swarm/network/stream: fix a goroutine leak in Registry (#19139)
    
    * swarm/network/stream: fix a goroutine leak in Registry
    
    * swarm/network, swamr/network/stream: Kademlia close addr count and depth change chans
    
    * swarm/network/stream: rename close channel to quit
    
    * swarm/network/stream: fix sync between NewRegistry goroutine and Close method

diff --git a/swarm/network/kademlia.go b/swarm/network/kademlia.go
index 146f39106..723f17f1c 100644
--- a/swarm/network/kademlia.go
+++ b/swarm/network/kademlia.go
@@ -333,6 +333,18 @@ func (k *Kademlia) NeighbourhoodDepthC() <-chan int {
 	return k.nDepthC
 }
 
+// CloseNeighbourhoodDepthC closes the channel returned by
+// NeighbourhoodDepthC and stops sending neighbourhood change.
+func (k *Kademlia) CloseNeighbourhoodDepthC() {
+	k.lock.Lock()
+	defer k.lock.Unlock()
+
+	if k.nDepthC != nil {
+		close(k.nDepthC)
+		k.nDepthC = nil
+	}
+}
+
 // sendNeighbourhoodDepthChange sends new neighbourhood depth to k.nDepth channel
 // if it is initialized.
 func (k *Kademlia) sendNeighbourhoodDepthChange() {
@@ -362,6 +374,18 @@ func (k *Kademlia) AddrCountC() <-chan int {
 	return k.addrCountC
 }
 
+// CloseAddrCountC closes the channel returned by
+// AddrCountC and stops sending address count change.
+func (k *Kademlia) CloseAddrCountC() {
+	k.lock.Lock()
+	defer k.lock.Unlock()
+
+	if k.addrCountC != nil {
+		close(k.addrCountC)
+		k.addrCountC = nil
+	}
+}
+
 // Off removes a peer from among live peers
 func (k *Kademlia) Off(p *Peer) {
 	k.lock.Lock()
diff --git a/swarm/network/stream/stream.go b/swarm/network/stream/stream.go
index 65bcce8b9..622b46e4c 100644
--- a/swarm/network/stream/stream.go
+++ b/swarm/network/stream/stream.go
@@ -95,6 +95,7 @@ type Registry struct {
 	spec           *protocols.Spec   //this protocol's spec
 	balance        protocols.Balance //implements protocols.Balance, for accounting
 	prices         protocols.Prices  //implements protocols.Prices, provides prices to accounting
+	quit           chan struct{}     // terminates registry goroutines
 }
 
 // RegistryOptions holds optional values for NewRegistry constructor.
@@ -117,6 +118,8 @@ func NewRegistry(localID enode.ID, delivery *Delivery, syncChunkStore storage.Sy
 	// check if retrieval has been disabled
 	retrieval := options.Retrieval != RetrievalDisabled
 
+	quit := make(chan struct{})
+
 	streamer := &Registry{
 		addr:           localID,
 		skipCheck:      options.SkipCheck,
@@ -128,6 +131,7 @@ func NewRegistry(localID enode.ID, delivery *Delivery, syncChunkStore storage.Sy
 		autoRetrieval:  retrieval,
 		maxPeerServers: options.MaxPeerServers,
 		balance:        balance,
+		quit:           quit,
 	}
 
 	streamer.setupSpec()
@@ -172,25 +176,41 @@ func NewRegistry(localID enode.ID, delivery *Delivery, syncChunkStore storage.Sy
 			go func() {
 				defer close(out)
 
-				for i := range in {
+				for {
 					select {
-					case <-out:
-					default:
+					case i, ok := <-in:
+						if !ok {
+							return
+						}
+						select {
+						case <-out:
+						default:
+						}
+						out <- i
+					case <-quit:
+						return
 					}
-					out <- i
 				}
 			}()
 
 			return out
 		}
 
+		kad := streamer.delivery.kad
+		// get notification channels from Kademlia before returning
+		// from this function to avoid race with Close method and
+		// the goroutine created below
+		depthC := latestIntC(kad.NeighbourhoodDepthC())
+		addressBookSizeC := latestIntC(kad.AddrCountC())
+
 		go func() {
 			// wait for kademlia table to be healthy
-			time.Sleep(options.SyncUpdateDelay)
-
-			kad := streamer.delivery.kad
-			depthC := latestIntC(kad.NeighbourhoodDepthC())
-			addressBookSizeC := latestIntC(kad.AddrCountC())
+			// but return if Registry is closed before
+			select {
+			case <-time.After(options.SyncUpdateDelay):
+			case <-quit:
+				return
+			}
 
 			// initial requests for syncing subscription to peers
 			streamer.updateSyncing()
@@ -229,6 +249,8 @@ func NewRegistry(localID enode.ID, delivery *Delivery, syncChunkStore storage.Sy
 							<-timer.C
 						}
 						timer.Reset(options.SyncUpdateDelay)
+					case <-quit:
+						break loop
 					}
 				}
 				timer.Stop()
@@ -398,6 +420,11 @@ func (r *Registry) Quit(peerId enode.ID, s Stream) error {
 }
 
 func (r *Registry) Close() error {
+	// Stop sending neighborhood depth change and address count
+	// change from Kademlia that were initiated in NewRegistry constructor.
+	r.delivery.kad.CloseNeighbourhoodDepthC()
+	r.delivery.kad.CloseAddrCountC()
+	close(r.quit)
 	return r.intervalsStore.Close()
 }
 
