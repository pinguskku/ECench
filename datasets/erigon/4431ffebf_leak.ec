commit 4431ffebf290e725429647aaa48d2cd24897c7bf
Author: Evgeny Danienko <6655321@bk.ru>
Date:   Thu Nov 7 18:44:43 2019 +0300

    goroutine leaks

diff --git a/accounts/accounts.go b/accounts/accounts.go
index 930033aa0..25892650b 100644
--- a/accounts/accounts.go
+++ b/accounts/accounts.go
@@ -169,6 +169,8 @@ type Backend interface {
 	// Subscribe creates an async subscription to receive notifications when the
 	// backend detects the arrival or departure of a wallet.
 	Subscribe(sink chan<- WalletEvent) event.Subscription
+
+	Close()
 }
 
 // TextHash is a helper function that calculates a hash for the given message that can be
diff --git a/accounts/external/backend.go b/accounts/external/backend.go
index c0e4a6a71..c1be78cc0 100644
--- a/accounts/external/backend.go
+++ b/accounts/external/backend.go
@@ -58,6 +58,12 @@ func (eb *ExternalBackend) Subscribe(sink chan<- accounts.WalletEvent) event.Sub
 	})
 }
 
+func (eb *ExternalBackend) Close() {
+	for _, w := range eb.signers {
+		w.Close()
+	}
+}
+
 // ExternalSigner provides an API to interact with an external signer (clef)
 // It proxies request to the external signer while forwarding relevant
 // request headers
diff --git a/accounts/keystore/keystore.go b/accounts/keystore/keystore.go
index 44d871227..17ab96c00 100644
--- a/accounts/keystore/keystore.go
+++ b/accounts/keystore/keystore.go
@@ -29,7 +29,6 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
-	"runtime"
 	"sync"
 	"time"
 
@@ -101,12 +100,6 @@ func (ks *KeyStore) init(keydir string) {
 	ks.unlocked = make(map[common.Address]*unlocked)
 	ks.cache, ks.changes = newAccountCache(keydir)
 
-	// TODO: In order for this finalizer to work, there must be no references
-	// to ks. addressCache doesn't keep a reference but unlocked keys do,
-	// so the finalizer will not trigger until all timed unlocks have expired.
-	runtime.SetFinalizer(ks, func(m *KeyStore) {
-		m.cache.close()
-	})
 	// Create the initial list of wallets from the cache
 	accs := ks.cache.accounts()
 	ks.wallets = make([]accounts.Wallet, len(accs))
@@ -487,6 +480,10 @@ func (ks *KeyStore) ImportPreSaleKey(keyJSON []byte, passphrase string) (account
 	return a, nil
 }
 
+func (ks *KeyStore) Close() {
+	ks.cache.close()
+}
+
 // zeroKey zeroes a private key in memory.
 func zeroKey(k *ecdsa.PrivateKey) {
 	b := k.D.Bits()
diff --git a/accounts/keystore/watch.go b/accounts/keystore/watch.go
index 8dce029a6..5967f2bc7 100644
--- a/accounts/keystore/watch.go
+++ b/accounts/keystore/watch.go
@@ -19,10 +19,11 @@
 package keystore
 
 import (
+	"sync/atomic"
 	"time"
 
+	"github.com/JekaMas/notify"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/rjeczalik/notify"
 )
 
 type watcher struct {
@@ -33,6 +34,8 @@ type watcher struct {
 	quit     chan struct{}
 }
 
+var watcherCount = new(uint32)
+
 func newWatcher(ac *accountCache) *watcher {
 	return &watcher{
 		ac:   ac,
@@ -57,6 +60,8 @@ func (w *watcher) close() {
 }
 
 func (w *watcher) loop() {
+	atomic.AddUint32(watcherCount, 1)
+
 	defer func() {
 		w.ac.mu.Lock()
 		w.running = false
@@ -69,7 +74,14 @@ func (w *watcher) loop() {
 		logger.Trace("Failed to watch keystore folder", "err", err)
 		return
 	}
-	defer notify.Stop(w.ev)
+
+	defer func() {
+		notify.Stop(w.ev)
+		if count := atomic.AddUint32(watcherCount, ^uint32(0)); count == 0 {
+			notify.Close()
+		}
+	}()
+
 	logger.Trace("Started watching keystore folder")
 	defer logger.Trace("Stopped watching keystore folder")
 
diff --git a/accounts/manager.go b/accounts/manager.go
index c0a77f1ae..c1311fd0c 100644
--- a/accounts/manager.go
+++ b/accounts/manager.go
@@ -70,7 +70,7 @@ func NewManager(config *Config, backends ...Backend) *Manager {
 		updaters: subs,
 		updates:  updates,
 		wallets:  wallets,
-		quit:     make(chan chan error),
+		quit:     make(chan chan error, 1),
 	}
 	for _, backend := range backends {
 		kind := reflect.TypeOf(backend)
@@ -85,6 +85,13 @@ func NewManager(config *Config, backends ...Backend) *Manager {
 func (am *Manager) Close() error {
 	errc := make(chan error)
 	am.quit <- errc
+
+	for _, backs := range am.backends {
+		for _, b := range backs {
+			b.Close()
+		}
+	}
+
 	return <-errc
 }
 
diff --git a/accounts/scwallet/hub.go b/accounts/scwallet/hub.go
index bede88781..2abbc9302 100644
--- a/accounts/scwallet/hub.go
+++ b/accounts/scwallet/hub.go
@@ -300,3 +300,7 @@ func (hub *Hub) updater() {
 		hub.stateLock.Unlock()
 	}
 }
+
+func (hub *Hub) Close() {
+	close(hub.quit)
+}
diff --git a/accounts/usbwallet/hub.go b/accounts/usbwallet/hub.go
index 7d7354d30..3cf92c073 100644
--- a/accounts/usbwallet/hub.go
+++ b/accounts/usbwallet/hub.go
@@ -278,3 +278,7 @@ func (hub *Hub) updater() {
 		hub.stateLock.Unlock()
 	}
 }
+
+func (hub *Hub) Close() {
+	close(hub.quit)
+}
\ No newline at end of file
diff --git a/dashboard/log.go b/dashboard/log.go
index 4213eb54e..a485d8a35 100644
--- a/dashboard/log.go
+++ b/dashboard/log.go
@@ -28,7 +28,7 @@ import (
 
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/mohae/deepcopy"
-	"github.com/rjeczalik/notify"
+	"github.com/JekaMas/notify"
 )
 
 var emptyChunk = json.RawMessage("[]")
diff --git a/eth/backend.go b/eth/backend.go
index 1d464b637..006ad5096 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -575,7 +575,7 @@ func (s *Ethereum) Stop() error {
 		s.lesServer.Stop()
 	}
 	s.txPool.Stop()
-	//s.miner.Stop()
+	//s.miner.Close()
 	s.eventMux.Stop()
 
 	s.chainDb.Close()
diff --git a/eth/fetcher/fetcher.go b/eth/fetcher/fetcher.go
index 2377813eb..0975dc473 100644
--- a/eth/fetcher/fetcher.go
+++ b/eth/fetcher/fetcher.go
@@ -640,7 +640,12 @@ func (f *Fetcher) insert(peer string, block *types.Block) {
 	// Run the import on a new thread
 	log.Debug("Importing propagated block", "peer", peer, "number", block.Number(), "hash", hash)
 	go func() {
-		defer func() { f.done <- hash }()
+		defer func() {
+			select {
+			case <-f.quit:
+			case f.done <- hash:
+			}
+		}()
 
 		// If the parent's unknown, abort insertion
 		parent := f.getBlock(block.ParentHash())
diff --git a/eth/filters/api.go b/eth/filters/api.go
index e056fda15..e62bcec64 100644
--- a/eth/filters/api.go
+++ b/eth/filters/api.go
@@ -66,6 +66,7 @@ func NewPublicFilterAPI(backend Backend, lightMode bool) *PublicFilterAPI {
 	api := &PublicFilterAPI{
 		backend: backend,
 		mux:     backend.EventMux(),
+		quit:    make(chan struct{}, 1),
 		chainDb: backend.ChainDb(),
 		events:  NewEventSystem(backend.EventMux(), backend, lightMode),
 		filters: make(map[rpc.ID]*filter),
@@ -80,7 +81,13 @@ func NewPublicFilterAPI(backend Backend, lightMode bool) *PublicFilterAPI {
 func (api *PublicFilterAPI) timeoutLoop() {
 	ticker := time.NewTicker(5 * time.Minute)
 	for {
-		<-ticker.C
+		select {
+		case <-ticker.C:
+		//nothing to do
+		case <-api.quit:
+			return
+		}
+
 		api.filtersMu.Lock()
 		for id, f := range api.filters {
 			select {
@@ -95,6 +102,10 @@ func (api *PublicFilterAPI) timeoutLoop() {
 	}
 }
 
+func (api *PublicFilterAPI) Close() {
+	close(api.quit)
+}
+
 // NewPendingTransactionFilter creates a filter that fetches pending transaction hashes
 // as transactions enter the pending state.
 //
@@ -126,6 +137,8 @@ func (api *PublicFilterAPI) NewPendingTransactionFilter() rpc.ID {
 				delete(api.filters, pendingTxSub.ID)
 				api.filtersMu.Unlock()
 				return
+			case <-api.quit:
+				return
 			}
 		}
 	}()
@@ -161,6 +174,8 @@ func (api *PublicFilterAPI) NewPendingTransactions(ctx context.Context) (*rpc.Su
 			case <-notifier.Closed():
 				pendingTxSub.Unsubscribe()
 				return
+			case <-api.quit:
+				return
 			}
 		}
 	}()
@@ -196,6 +211,8 @@ func (api *PublicFilterAPI) NewBlockFilter() rpc.ID {
 				delete(api.filters, headerSub.ID)
 				api.filtersMu.Unlock()
 				return
+			case <-api.quit:
+				return
 			}
 		}
 	}()
@@ -226,6 +243,8 @@ func (api *PublicFilterAPI) NewHeads(ctx context.Context) (*rpc.Subscription, er
 			case <-notifier.Closed():
 				headersSub.Unsubscribe()
 				return
+			case <-api.quit:
+				return
 			}
 		}
 	}()
@@ -264,6 +283,8 @@ func (api *PublicFilterAPI) Logs(ctx context.Context, crit FilterCriteria) (*rpc
 			case <-notifier.Closed(): // connection dropped
 				logsSub.Unsubscribe()
 				return
+			case <-api.quit:
+				return
 			}
 		}
 	}()
@@ -313,6 +334,8 @@ func (api *PublicFilterAPI) NewFilter(crit FilterCriteria) (rpc.ID, error) {
 				delete(api.filters, logsSub.ID)
 				api.filtersMu.Unlock()
 				return
+			case <-api.quit:
+				return
 			}
 		}
 	}()
diff --git a/go.mod b/go.mod
index 3a17718f0..1aa770eb2 100644
--- a/go.mod
+++ b/go.mod
@@ -5,6 +5,7 @@ go 1.12
 require (
 	github.com/Azure/azure-storage-blob-go v0.8.0
 	github.com/Azure/go-autorest/autorest/adal v0.8.0 // indirect
+	github.com/JekaMas/notify v0.9.1
 	github.com/StackExchange/wmi v0.0.0-20190523213315-cbe66965904d // indirect
 	github.com/allegro/bigcache v0.0.0-20181022200625-bff00e20c68d
 	github.com/apilayer/freegeoip v3.5.0+incompatible
@@ -50,7 +51,6 @@ require (
 	github.com/petar/GoLLRB v0.0.0-20190514000832-33fb24c13b99
 	github.com/peterh/liner v0.0.0-20190123174540-a2c9a5303de7
 	github.com/prometheus/tsdb v0.10.0
-	github.com/rjeczalik/notify v0.9.1
 	github.com/robertkrimen/otto v0.0.0-20170205013659-6a77b7cbc37d
 	github.com/rs/cors v0.0.0-20160617231935-a62a804a8a00
 	github.com/rs/xhandler v0.0.0-20170707052532-1eb70cf1520d // indirect
diff --git a/go.sum b/go.sum
index 25833d6a3..191d7f959 100644
--- a/go.sum
+++ b/go.sum
@@ -19,6 +19,8 @@ github.com/Azure/go-autorest/logger v0.1.0/go.mod h1:oExouG+K6PryycPJfVSxi/koC6L
 github.com/Azure/go-autorest/tracing v0.5.0 h1:TRn4WjSnkcSy5AEG3pnbtFSwNtwzjr4VYyQflFE619k=
 github.com/Azure/go-autorest/tracing v0.5.0/go.mod h1:r/s2XiOKccPW3HrqB+W0TQzfbtp2fGCgRFtBroKn4Dk=
 github.com/BurntSushi/toml v0.3.1/go.mod h1:xHWCNGjB5oqiDr8zfno3MHue2Ht5sIBksp03qcyfWMU=
+github.com/JekaMas/notify v0.9.1 h1:JBgfYqxk4Ck1vtX6RvbcHyO82HZQSMWwjyP08X7qbd4=
+github.com/JekaMas/notify v0.9.1/go.mod h1:9nWOMMZVbJ1o/p9JUZ/zf03728qiYgO+w3ZTo/QP/TU=
 github.com/OneOfOne/xxhash v1.2.2/go.mod h1:HSdplMjZKSmBqAxg5vPj2TmRDmfkzw+cTzAElWljhcU=
 github.com/StackExchange/wmi v0.0.0-20190523213315-cbe66965904d h1:G0m3OIz70MZUWq3EgK3CesDbo8upS2Vm9/P3FtgI+Jk=
 github.com/StackExchange/wmi v0.0.0-20190523213315-cbe66965904d/go.mod h1:3eOhrUMpNV+6aFIbp5/iudMxNCF27Vw2OZgy4xEx0Fg=
@@ -169,8 +171,6 @@ github.com/prometheus/procfs v0.0.0-20181005140218-185b4288413d/go.mod h1:c3At6R
 github.com/prometheus/procfs v0.0.2/go.mod h1:TjEm7ze935MbeOT/UhFTIMYKhuLP4wbCsTZCD3I8kEA=
 github.com/prometheus/tsdb v0.10.0 h1:If5rVCMTp6W2SiRAQFlbpJNgVlgMEd+U2GZckwK38ic=
 github.com/prometheus/tsdb v0.10.0/go.mod h1:oi49uRhEe9dPUTlS3JRZOwJuVi6tmh10QSgwXEyGCt4=
-github.com/rjeczalik/notify v0.9.1 h1:CLCKso/QK1snAlnhNR/CNvNiFU2saUtjV0bx3EwNeCE=
-github.com/rjeczalik/notify v0.9.1/go.mod h1:rKwnCoCGeuQnwBtTSPL9Dad03Vh2n40ePRrjvIXnJho=
 github.com/robertkrimen/otto v0.0.0-20170205013659-6a77b7cbc37d h1:ouzpe+YhpIfnjR40gSkJHWsvXmB6TiPKqMtMpfyU9DE=
 github.com/robertkrimen/otto v0.0.0-20170205013659-6a77b7cbc37d/go.mod h1:xvqspoSXJTIpemEonrMDFq6XzwHYYgToXWj5eRX1OtY=
 github.com/rs/cors v0.0.0-20160617231935-a62a804a8a00 h1:8DPul/X0IT/1TNMIxoKLwdemEOBBHDC/K4EB16Cw5WE=
@@ -253,4 +253,4 @@ gopkg.in/yaml.v2 v2.2.1/go.mod h1:hI93XBmqTisBFMUTm0b8Fm+jr3Dg1NNxqwp+5A1VGuI=
 gopkg.in/yaml.v2 v2.2.2 h1:ZCJp+EgiOT7lHqUV2J862kp8Qj64Jo6az82+3Td9dZw=
 gopkg.in/yaml.v2 v2.2.2/go.mod h1:hI93XBmqTisBFMUTm0b8Fm+jr3Dg1NNxqwp+5A1VGuI=
 gotest.tools v2.2.0+incompatible h1:VsBPFP1AI068pPrMxtb/S8Zkgf9xEmTLJjfM+P5UIEo=
-gotest.tools v2.2.0+incompatible/go.mod h1:DsYFclhRJ6vuDpmuTbkuFWG+y2sxOXAzmJt81HFBacw=
\ No newline at end of file
+gotest.tools v2.2.0+incompatible/go.mod h1:DsYFclhRJ6vuDpmuTbkuFWG+y2sxOXAzmJt81HFBacw=
diff --git a/miner/miner.go b/miner/miner.go
index 081f5502a..eb6aa1d02 100644
--- a/miner/miner.go
+++ b/miner/miner.go
@@ -138,6 +138,7 @@ func (mnr *Miner) Stop() {
 }
 
 func (mnr *Miner) Close() {
+	mnr.worker.stop()
 	mnr.worker.close()
 	close(mnr.exitCh)
 }
diff --git a/miner/worker.go b/miner/worker.go
index 85cd9d8dd..8d5c91153 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -196,8 +196,8 @@ func newWorker(config *Config, chainConfig *params.ChainConfig, engine consensus
 		txsCh:              make(chan core.NewTxsEvent, txChanSize),
 		chainHeadCh:        make(chan core.ChainHeadEvent, chainHeadChanSize),
 		chainSideCh:        make(chan core.ChainSideEvent, chainSideChanSize),
-		newWorkCh:          make(chan *newWorkReq),
-		taskCh:             make(chan *task),
+		newWorkCh:          make(chan *newWorkReq, 1),
+		taskCh:             make(chan *task, 1),
 		resultCh:           make(chan *types.Block, resultQueueSize),
 		exitCh:             make(chan struct{}),
 		startCh:            make(chan struct{}, 1),
diff --git a/node/node.go b/node/node.go
index ea24cd3fb..30676f424 100644
--- a/node/node.go
+++ b/node/node.go
@@ -438,6 +438,18 @@ func (n *Node) Stop() error {
 	n.stopWS()
 	n.stopHTTP()
 	n.stopIPC()
+
+	type stop interface {
+		Close()
+	}
+
+	for _, api := range n.rpcAPIs {
+		closeAPI, ok := api.Service.(stop)
+		if ok {
+			closeAPI.Close()
+		}
+	}
+
 	n.rpcAPIs = nil
 	failure := &StopError{
 		Services: make(map[reflect.Type]error),
diff --git a/p2p/dial.go b/p2p/dial.go
index 87cd77d75..56ee2e531 100644
--- a/p2p/dial.go
+++ b/p2p/dial.go
@@ -356,7 +356,7 @@ func (t *discoverTask) Do(srv *Server) {
 	// event loop spins too fast.
 	next := srv.lastLookup.Add(lookupInterval)
 	if now := time.Now(); now.Before(next) {
-		time.Sleep(next.Sub(now))
+		sleep(next.Sub(now), srv)
 	}
 	srv.lastLookup = time.Now()
 	t.results = srv.ntab.LookupRandom()
@@ -370,9 +370,21 @@ func (t *discoverTask) String() string {
 	return s
 }
 
-func (t waitExpireTask) Do(*Server) {
-	time.Sleep(t.Duration)
+func (t waitExpireTask) Do(srv *Server) {
+	sleep(t.Duration, srv)
 }
 func (t waitExpireTask) String() string {
 	return fmt.Sprintf("wait for dial hist expire (%v)", t.Duration)
 }
+
+func sleep(d time.Duration, srv *Server) {
+	timer := time.NewTimer(d)
+	defer timer.Stop()
+
+	select {
+	case <-timer.C:
+		//nothing to do
+	case <-srv.quit:
+		return
+	}
+}
diff --git a/p2p/server.go b/p2p/server.go
index ebf79473c..8b7b29fba 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -381,11 +381,11 @@ func (srv *Server) Stop() {
 		return
 	}
 	srv.running = false
+	close(srv.quit)
 	if srv.listener != nil {
 		// this unblocks listener Accept
 		srv.listener.Close()
 	}
-	close(srv.quit)
 	srv.lock.Unlock()
 	srv.loopWG.Wait()
 }
@@ -650,7 +650,21 @@ func (srv *Server) run(dialstate dialer) {
 		for ; len(runningTasks) < maxActiveDialTasks && i < len(ts); i++ {
 			t := ts[i]
 			srv.log.Trace("New dial task", "task", t)
-			go func() { t.Do(srv); taskdone <- t }()
+
+			go func() {
+				select {
+				case <-srv.quit:
+					return
+				default:
+					t.Do(srv)
+				}
+
+				select {
+				case <-srv.quit:
+					return
+				case taskdone <- t:
+				}
+			}()
 			runningTasks = append(runningTasks, t)
 		}
 		return ts[i:]
