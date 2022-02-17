commit 3e9ba576694e7df018b3c9fa2c1d3aa7d55031fe
Author: Anton Evangelatov <anton.evangelatov@gmail.com>
Date:   Tue May 7 13:46:26 2019 +0200

    swarm/storage: improve instrumentation
    
    swarm/storage/localstore: fix broken metric (#1373)
    
    p2p/protocols: count different messages (#1374)
    
    cmd/swarm: disable snapshot create test due to constant flakes (#1376)
    
    swarm/network: remove redundant goroutine (#1377)

diff --git a/cmd/swarm/swarm-snapshot/create_test.go b/cmd/swarm/swarm-snapshot/create_test.go
index b2e30c201..17745af5d 100644
--- a/cmd/swarm/swarm-snapshot/create_test.go
+++ b/cmd/swarm/swarm-snapshot/create_test.go
@@ -21,7 +21,6 @@ import (
 	"fmt"
 	"io/ioutil"
 	"os"
-	"runtime"
 	"sort"
 	"strconv"
 	"strings"
@@ -34,9 +33,7 @@ import (
 // It runs a few "create" commands with different flag values and loads generated
 // snapshot files to validate their content.
 func TestSnapshotCreate(t *testing.T) {
-	if runtime.GOOS == "windows" {
-		t.Skip()
-	}
+	t.Skip("todo: fix this")
 
 	for _, v := range []struct {
 		name     string
diff --git a/p2p/protocols/protocol.go b/p2p/protocols/protocol.go
index 164e3fa4b..a9a00984d 100644
--- a/p2p/protocols/protocol.go
+++ b/p2p/protocols/protocol.go
@@ -254,6 +254,7 @@ func (p *Peer) Drop() {
 func (p *Peer) Send(ctx context.Context, msg interface{}) error {
 	defer metrics.GetOrRegisterResettingTimer("peer.send_t", nil).UpdateSince(time.Now())
 	metrics.GetOrRegisterCounter("peer.send", nil).Inc(1)
+	metrics.GetOrRegisterCounter(fmt.Sprintf("peer.send.%T", msg), nil).Inc(1)
 
 	var b bytes.Buffer
 	if tracing.Enabled {
diff --git a/swarm/network/stream/messages.go b/swarm/network/stream/messages.go
index b43fdeee2..339101b88 100644
--- a/swarm/network/stream/messages.go
+++ b/swarm/network/stream/messages.go
@@ -24,9 +24,7 @@ import (
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/swarm/log"
 	bv "github.com/ethereum/go-ethereum/swarm/network/bitvector"
-	"github.com/ethereum/go-ethereum/swarm/spancontext"
 	"github.com/ethereum/go-ethereum/swarm/storage"
-	"github.com/opentracing/opentracing-go"
 )
 
 var syncBatchTimeout = 30 * time.Second
@@ -201,12 +199,6 @@ func (m OfferedHashesMsg) String() string {
 func (p *Peer) handleOfferedHashesMsg(ctx context.Context, req *OfferedHashesMsg) error {
 	metrics.GetOrRegisterCounter("peer.handleofferedhashes", nil).Inc(1)
 
-	var sp opentracing.Span
-	ctx, sp = spancontext.StartSpan(
-		ctx,
-		"handle.offered.hashes")
-	defer sp.Finish()
-
 	c, _, err := p.getOrSetClient(req.Stream, req.From, req.To)
 	if err != nil {
 		return err
@@ -297,34 +289,34 @@ func (p *Peer) handleOfferedHashesMsg(ctx context.Context, req *OfferedHashesMsg
 		From:   from,
 		To:     to,
 	}
-	go func() {
-		log.Trace("sending want batch", "peer", p.ID(), "stream", msg.Stream, "from", msg.From, "to", msg.To)
-		select {
-		case err := <-c.next:
-			if err != nil {
-				log.Warn("c.next error dropping peer", "err", err)
-				p.Drop()
-				return
-			}
-		case <-c.quit:
-			log.Debug("client.handleOfferedHashesMsg() quit")
-			return
-		case <-ctx.Done():
-			log.Debug("client.handleOfferedHashesMsg() context done", "ctx.Err()", ctx.Err())
-			return
-		}
-		log.Trace("sending want batch", "peer", p.ID(), "stream", msg.Stream, "from", msg.From, "to", msg.To)
-
-		// record want delay
-		if wantDelaySet {
-			metrics.GetOrRegisterResettingTimer("handleoffered.wantdelay", nil).UpdateSince(wantDelay)
-		}
 
-		err := p.SendPriority(ctx, msg, c.priority)
+	log.Trace("sending want batch", "peer", p.ID(), "stream", msg.Stream, "from", msg.From, "to", msg.To)
+	select {
+	case err := <-c.next:
 		if err != nil {
-			log.Warn("SendPriority error", "err", err)
+			log.Warn("c.next error dropping peer", "err", err)
+			p.Drop()
+			return err
 		}
-	}()
+	case <-c.quit:
+		log.Debug("client.handleOfferedHashesMsg() quit")
+		return nil
+	case <-ctx.Done():
+		log.Debug("client.handleOfferedHashesMsg() context done", "ctx.Err()", ctx.Err())
+		return nil
+	}
+	log.Trace("sending want batch", "peer", p.ID(), "stream", msg.Stream, "from", msg.From, "to", msg.To)
+
+	// record want delay
+	if wantDelaySet {
+		metrics.GetOrRegisterResettingTimer("handleoffered.wantdelay", nil).UpdateSince(wantDelay)
+	}
+
+	err = p.SendPriority(ctx, msg, c.priority)
+	if err != nil {
+		log.Warn("SendPriority error", "err", err)
+	}
+
 	return nil
 }
 
diff --git a/swarm/storage/localstore/localstore.go b/swarm/storage/localstore/localstore.go
index c32d2972d..3b0bd8a93 100644
--- a/swarm/storage/localstore/localstore.go
+++ b/swarm/storage/localstore/localstore.go
@@ -73,7 +73,7 @@ type DB struct {
 	pullTriggers   map[uint8][]chan struct{}
 	pullTriggersMu sync.RWMutex
 
-	// binIDs stores the latest chunk serial ID for very
+	// binIDs stores the latest chunk serial ID for every
 	// proximity order bin
 	binIDs shed.Uint64Vector
 
diff --git a/swarm/storage/localstore/mode_get.go b/swarm/storage/localstore/mode_get.go
index 48603550c..191f4ebe5 100644
--- a/swarm/storage/localstore/mode_get.go
+++ b/swarm/storage/localstore/mode_get.go
@@ -47,7 +47,7 @@ func (db *DB) Get(ctx context.Context, mode chunk.ModeGet, addr chunk.Address) (
 
 	defer func() {
 		if err != nil {
-			metrics.GetOrRegisterCounter(fmt.Sprintf(metricName+".error", mode), nil).Inc(1)
+			metrics.GetOrRegisterCounter(metricName+".error", nil).Inc(1)
 		}
 	}()
 
diff --git a/swarm/storage/localstore/subscription_pull.go b/swarm/storage/localstore/subscription_pull.go
index 7a18141b3..dd07add53 100644
--- a/swarm/storage/localstore/subscription_pull.go
+++ b/swarm/storage/localstore/subscription_pull.go
@@ -36,7 +36,7 @@ import (
 // Pull syncing index can be only subscribed to a particular proximity order bin. If since
 // is not 0, the iteration will start from the first item stored after that id. If until is not 0,
 // only chunks stored up to this id will be sent to the channel, and the returned channel will be
-// closed. The since-until interval is closed on the both sides [since,until]. Returned stop
+// closed. The since-until interval is open on since side, and closed on until side: (since,until] <=> [since+1,until]. Returned stop
 // function will terminate current and further iterations without errors, and also close the returned channel.
 // Make sure that you check the second returned parameter from the channel to stop iteration when its value
 // is false.
