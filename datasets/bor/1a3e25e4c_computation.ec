commit 1a3e25e4c11d09aabd77402585412f1577251f49
Author: Anton Evangelatov <anton.evangelatov@gmail.com>
Date:   Mon Mar 11 11:45:34 2019 +0100

    swarm: tracing improvements (#19249)

diff --git a/cmd/swarm/swarm-smoke/upload_and_sync.go b/cmd/swarm/swarm-smoke/upload_and_sync.go
index 50af122e7..23b7d5688 100644
--- a/cmd/swarm/swarm-smoke/upload_and_sync.go
+++ b/cmd/swarm/swarm-smoke/upload_and_sync.go
@@ -68,55 +68,45 @@ func uploadAndSyncCmd(ctx *cli.Context, tuid string) error {
 }
 
 func trackChunks(testData []byte) error {
-	log.Warn("Test timed out; running chunk debug sequence")
+	log.Warn("Test timed out, running chunk debug sequence")
 
 	addrs, err := getAllRefs(testData)
 	if err != nil {
 		return err
 	}
-	log.Trace("All references retrieved")
 
 	for i, ref := range addrs {
 		log.Trace(fmt.Sprintf("ref %d", i), "ref", ref)
 	}
 
-	// has-chunks
 	for _, host := range hosts {
 		httpHost := fmt.Sprintf("ws://%s:%d", host, 8546)
-		log.Trace("Calling `Has` on host", "httpHost", httpHost)
 
 		hostChunks := []string{}
 
 		rpcClient, err := rpc.Dial(httpHost)
 		if err != nil {
-			log.Trace("Error dialing host", "err", err)
+			log.Error("Error dialing host", "err", err)
 			return err
 		}
-		log.Trace("rpc dial ok")
+
 		var hasInfo []api.HasInfo
 		err = rpcClient.Call(&hasInfo, "bzz_has", addrs)
 		if err != nil {
-			log.Trace("Error calling host", "err", err)
+			log.Error("Error calling host", "err", err)
 			return err
 		}
-		log.Trace("rpc call ok")
-		count := 0
-		for i, info := range hasInfo {
-			if i == 0 {
-				log.Trace("first hasInfo", "addr", info.Addr, "host", host, "i", i)
-			}
-			if i == len(hasInfo)-1 {
-				log.Trace("last hasInfo", "addr", info.Addr, "host", host, "i", i)
-			}
 
+		count := 0
+		for _, info := range hasInfo {
 			if info.Has {
 				hostChunks = append(hostChunks, "1")
 			} else {
 				hostChunks = append(hostChunks, "0")
 				count++
 			}
-
 		}
+
 		if count == 0 {
 			log.Info("host reported to have all chunks", "host", host)
 		}
diff --git a/swarm/network/fetcher.go b/swarm/network/fetcher.go
index 3e6bb8904..f7deead3d 100644
--- a/swarm/network/fetcher.go
+++ b/swarm/network/fetcher.go
@@ -26,7 +26,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/swarm/storage"
 	"github.com/ethereum/go-ethereum/swarm/tracing"
-	"github.com/opentracing/opentracing-go"
+	olog "github.com/opentracing/opentracing-go/log"
 )
 
 const (
@@ -327,7 +327,8 @@ func (f *Fetcher) doRequest(gone chan *enode.ID, peersToSkip *sync.Map, sources
 		span := tracing.ShiftSpanByKey(spanId)
 
 		if span != nil {
-			defer span.(opentracing.Span).Finish()
+			span.LogFields(olog.String("finish", "from doRequest"))
+			span.Finish()
 		}
 	}()
 	return sources, nil
diff --git a/swarm/network/stream/delivery.go b/swarm/network/stream/delivery.go
index 02c5f222c..01ae7f943 100644
--- a/swarm/network/stream/delivery.go
+++ b/swarm/network/stream/delivery.go
@@ -29,6 +29,7 @@ import (
 	"github.com/ethereum/go-ethereum/swarm/storage"
 	"github.com/ethereum/go-ethereum/swarm/tracing"
 	opentracing "github.com/opentracing/opentracing-go"
+	olog "github.com/opentracing/opentracing-go/log"
 )
 
 const (
@@ -146,6 +147,8 @@ func (d *Delivery) handleRetrieveRequestMsg(ctx context.Context, sp *Peer, req *
 		ctx,
 		"stream.handle.retrieve")
 
+	osp.LogFields(olog.String("ref", req.Addr.String()))
+
 	s, err := sp.getServer(NewStream(swarmChunkServerStreamName, "", true))
 	if err != nil {
 		return err
@@ -176,12 +179,15 @@ func (d *Delivery) handleRetrieveRequestMsg(ctx context.Context, sp *Peer, req *
 		}
 		if req.SkipCheck {
 			syncing := false
+			osp.LogFields(olog.Bool("skipCheck", true))
+
 			err = sp.Deliver(ctx, chunk, s.priority, syncing)
 			if err != nil {
 				log.Warn("ERROR in handleRetrieveRequestMsg", "err", err)
 			}
 			return
 		}
+		osp.LogFields(olog.Bool("skipCheck", false))
 		select {
 		case streamer.deliveryC <- chunk.Address()[:]:
 		case <-streamer.quit:
@@ -219,7 +225,8 @@ func (d *Delivery) handleChunkDeliveryMsg(ctx context.Context, sp *Peer, req *Ch
 
 	go func() {
 		if span != nil {
-			defer span.(opentracing.Span).Finish()
+			span.LogFields(olog.String("finish", "from handleChunkDeliveryMsg"))
+			defer span.Finish()
 		}
 
 		req.peer = sp
diff --git a/swarm/network/stream/peer.go b/swarm/network/stream/peer.go
index 0f1472743..152814bd4 100644
--- a/swarm/network/stream/peer.go
+++ b/swarm/network/stream/peer.go
@@ -167,9 +167,8 @@ func (p *Peer) SendPriority(ctx context.Context, msg interface{}, priority uint8
 		Msg:     msg,
 	}
 	err := p.pq.Push(wmsg, int(priority))
-	if err == pq.ErrContention {
-		log.Warn("dropping peer on priority queue contention", "peer", p.ID())
-		p.Drop(err)
+	if err != nil {
+		log.Error("err on p.pq.Push", "err", err, "peer", p.ID())
 	}
 	return err
 }
@@ -183,6 +182,8 @@ func (p *Peer) SendOfferedHashes(s *server, f, t uint64) error {
 	)
 	defer sp.Finish()
 
+	defer metrics.GetOrRegisterResettingTimer("send.offered.hashes", nil).UpdateSince(time.Now())
+
 	hashes, from, to, proof, err := s.setNextBatch(f, t)
 	if err != nil {
 		return err
diff --git a/swarm/storage/netstore.go b/swarm/storage/netstore.go
index cb6c1c9cf..e3845489e 100644
--- a/swarm/storage/netstore.go
+++ b/swarm/storage/netstore.go
@@ -103,6 +103,14 @@ func (n *NetStore) Get(rctx context.Context, ref Address) (Chunk, error) {
 		return nil, err
 	}
 	if chunk != nil {
+		// this is not measuring how long it takes to get the chunk for the localstore, but
+		// rather just adding a span for clarity when inspecting traces in Jaeger, in order
+		// to make it easier to reason which is the node that actually delivered a chunk.
+		_, sp := spancontext.StartSpan(
+			rctx,
+			"localstore.get")
+		defer sp.Finish()
+
 		return chunk, nil
 	}
 	return fetch(rctx)
