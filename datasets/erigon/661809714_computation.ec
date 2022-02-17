commit 661809714e35f69dea23f713dd1e65cff523344c
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Fri Dec 7 06:51:40 2018 +0100

    swarm: snapshot load improvement (#18220)
    
    * swarm/network: Hive - do not notify peer if discovery is disabled
    
    * p2p/simulations: validate all connections on loading a snapshot
    
    * p2p/simulations: track all connections in on snapshot loading
    
    * p2p/simulations: add snapshotLoadTimeout variable
    
    * p2p/simulations: ignore control events in snapshot load
    
    * p2p/simulations: simplify event loop synchronization
    
    * p2p/simulations: return already connected error from Load function
    
    * p2p/simulations: log warning on snapshot loading disconnection

diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 92ccfde81..ab9f582c5 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -20,6 +20,7 @@ import (
 	"bytes"
 	"context"
 	"encoding/json"
+	"errors"
 	"fmt"
 	"sync"
 	"time"
@@ -705,8 +706,11 @@ func (net *Network) snapshot(addServices []string, removeServices []string) (*Sn
 	return snap, nil
 }
 
+var snapshotLoadTimeout = 120 * time.Second
+
 // Load loads a network snapshot
 func (net *Network) Load(snap *Snapshot) error {
+	// Start nodes.
 	for _, n := range snap.Nodes {
 		if _, err := net.NewNodeWithConfig(n.Node.Config); err != nil {
 			return err
@@ -718,6 +722,69 @@ func (net *Network) Load(snap *Snapshot) error {
 			return err
 		}
 	}
+
+	// Prepare connection events counter.
+	allConnected := make(chan struct{}) // closed when all connections are established
+	done := make(chan struct{})         // ensures that the event loop goroutine is terminated
+	defer close(done)
+
+	// Subscribe to event channel.
+	// It needs to be done outside of the event loop goroutine (created below)
+	// to ensure that the event channel is blocking before connect calls are made.
+	events := make(chan *Event)
+	sub := net.Events().Subscribe(events)
+	defer sub.Unsubscribe()
+
+	go func() {
+		// Expected number of connections.
+		total := len(snap.Conns)
+		// Set of all established connections from the snapshot, not other connections.
+		// Key array element 0 is the connection One field value, and element 1 connection Other field.
+		connections := make(map[[2]enode.ID]struct{}, total)
+
+		for {
+			select {
+			case e := <-events:
+				// Ignore control events as they do not represent
+				// connect or disconnect (Up) state change.
+				if e.Control {
+					continue
+				}
+				// Detect only connection events.
+				if e.Type != EventTypeConn {
+					continue
+				}
+				connection := [2]enode.ID{e.Conn.One, e.Conn.Other}
+				// Nodes are still not connected or have been disconnected.
+				if !e.Conn.Up {
+					// Delete the connection from the set of established connections.
+					// This will prevent false positive in case disconnections happen.
+					delete(connections, connection)
+					log.Warn("load snapshot: unexpected disconnection", "one", e.Conn.One, "other", e.Conn.Other)
+					continue
+				}
+				// Check that the connection is from the snapshot.
+				for _, conn := range snap.Conns {
+					if conn.One == e.Conn.One && conn.Other == e.Conn.Other {
+						// Add the connection to the set of established connections.
+						connections[connection] = struct{}{}
+						if len(connections) == total {
+							// Signal that all nodes are connected.
+							close(allConnected)
+							return
+						}
+
+						break
+					}
+				}
+			case <-done:
+				// Load function returned, terminate this goroutine.
+				return
+			}
+		}
+	}()
+
+	// Start connecting.
 	for _, conn := range snap.Conns {
 
 		if !net.GetNode(conn.One).Up || !net.GetNode(conn.Other).Up {
@@ -729,6 +796,14 @@ func (net *Network) Load(snap *Snapshot) error {
 			return err
 		}
 	}
+
+	select {
+	// Wait until all connections from the snapshot are established.
+	case <-allConnected:
+	// Make sure that we do not wait forever.
+	case <-time.After(snapshotLoadTimeout):
+		return errors.New("snapshot connections not established")
+	}
 	return nil
 }
 
diff --git a/swarm/network/hive.go b/swarm/network/hive.go
index 1aa1ae42a..ebef54592 100644
--- a/swarm/network/hive.go
+++ b/swarm/network/hive.go
@@ -165,8 +165,8 @@ func (h *Hive) Run(p *BzzPeer) error {
 			// otherwise just send depth to new peer
 			dp.NotifyDepth(depth)
 		}
+		NotifyPeer(p.BzzAddr, h.Kademlia)
 	}
-	NotifyPeer(p.BzzAddr, h.Kademlia)
 	defer h.Off(dp)
 	return dp.Run(dp.HandleMsg)
 }
diff --git a/swarm/network/simulation/kademlia_test.go b/swarm/network/simulation/kademlia_test.go
index 024830315..f02b0e541 100644
--- a/swarm/network/simulation/kademlia_test.go
+++ b/swarm/network/simulation/kademlia_test.go
@@ -33,7 +33,6 @@ func TestWaitTillHealthy(t *testing.T) {
 		"bzz": func(ctx *adapters.ServiceContext, b *sync.Map) (node.Service, func(), error) {
 			addr := network.NewAddr(ctx.Config.Node())
 			hp := network.NewHiveParams()
-			hp.Discovery = false
 			config := &network.BzzConfig{
 				OverlayAddr:  addr.Over(),
 				UnderlayAddr: addr.Under(),
