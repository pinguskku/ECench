commit c2003ed63b975c6318e4dd7e65b69c60777b0ddf
Author: Felföldi Zsolt <zsfelfoldi@gmail.com>
Date:   Tue Feb 26 12:32:48 2019 +0100

    les, les/flowcontrol: improved request serving and flow control (#18230)
    
    This change
    
    - implements concurrent LES request serving even for a single peer.
    - replaces the request cost estimation method with a cost table based on
      benchmarks which gives much more consistent results. Until now the
      allowed number of light peers was just a guess which probably contributed
      a lot to the fluctuating quality of available service. Everything related
      to request cost is implemented in a single object, the 'cost tracker'. It
      uses a fixed cost table with a global 'correction factor'. Benchmark code
      is included and can be run at any time to adapt costs to low-level
      implementation changes.
    - reimplements flowcontrol.ClientManager in a cleaner and more efficient
      way, with added capabilities: There is now control over bandwidth, which
      allows using the flow control parameters for client prioritization.
      Target utilization over 100 percent is now supported to model concurrent
      request processing. Total serving bandwidth is reduced during block
      processing to prevent database contention.
    - implements an RPC API for the LES servers allowing server operators to
      assign priority bandwidth to certain clients and change prioritized
      status even while the client is connected. The new API is meant for
      cases where server operators charge for LES using an off-protocol mechanism.
    - adds a unit test for the new client manager.
    - adds an end-to-end test using the network simulator that tests bandwidth
      control functions through the new API.

diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index 17bf438e2..a331abc9f 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -93,6 +93,8 @@ var (
 		utils.ExitWhenSyncedFlag,
 		utils.GCModeFlag,
 		utils.LightServFlag,
+		utils.LightBandwidthInFlag,
+		utils.LightBandwidthOutFlag,
 		utils.LightPeersFlag,
 		utils.LightKDFFlag,
 		utils.WhitelistFlag,
diff --git a/cmd/geth/usage.go b/cmd/geth/usage.go
index a26203716..0338e447e 100644
--- a/cmd/geth/usage.go
+++ b/cmd/geth/usage.go
@@ -81,6 +81,8 @@ var AppHelpFlagGroups = []flagGroup{
 			utils.EthStatsURLFlag,
 			utils.IdentityFlag,
 			utils.LightServFlag,
+			utils.LightBandwidthInFlag,
+			utils.LightBandwidthOutFlag,
 			utils.LightPeersFlag,
 			utils.LightKDFFlag,
 			utils.WhitelistFlag,
diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index 5b8ebb481..4db59097d 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -199,9 +199,19 @@ var (
 	}
 	LightServFlag = cli.IntFlag{
 		Name:  "lightserv",
-		Usage: "Maximum percentage of time allowed for serving LES requests (0-90)",
+		Usage: "Maximum percentage of time allowed for serving LES requests (multi-threaded processing allows values over 100)",
 		Value: 0,
 	}
+	LightBandwidthInFlag = cli.IntFlag{
+		Name:  "lightbwin",
+		Usage: "Incoming bandwidth limit for light server (1000 bytes/sec, 0 = unlimited)",
+		Value: 1000,
+	}
+	LightBandwidthOutFlag = cli.IntFlag{
+		Name:  "lightbwout",
+		Usage: "Outgoing bandwidth limit for light server (1000 bytes/sec, 0 = unlimited)",
+		Value: 5000,
+	}
 	LightPeersFlag = cli.IntFlag{
 		Name:  "lightpeers",
 		Usage: "Maximum number of LES client peers",
@@ -1305,6 +1315,8 @@ func SetEthConfig(ctx *cli.Context, stack *node.Node, cfg *eth.Config) {
 	if ctx.GlobalIsSet(LightServFlag.Name) {
 		cfg.LightServ = ctx.GlobalInt(LightServFlag.Name)
 	}
+	cfg.LightBandwidthIn = ctx.GlobalInt(LightBandwidthInFlag.Name)
+	cfg.LightBandwidthOut = ctx.GlobalInt(LightBandwidthOutFlag.Name)
 	if ctx.GlobalIsSet(LightPeersFlag.Name) {
 		cfg.LightPeers = ctx.GlobalInt(LightPeersFlag.Name)
 	}
diff --git a/core/blockchain.go b/core/blockchain.go
index d6dad2799..7b4f4b303 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -111,6 +111,7 @@ type BlockChain struct {
 	chainSideFeed event.Feed
 	chainHeadFeed event.Feed
 	logsFeed      event.Feed
+	blockProcFeed event.Feed
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
@@ -1090,6 +1091,10 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	if len(chain) == 0 {
 		return 0, nil
 	}
+
+	bc.blockProcFeed.Send(true)
+	defer bc.blockProcFeed.Send(false)
+
 	// Remove already known canon-blocks
 	var (
 		block, prev *types.Block
@@ -1725,3 +1730,9 @@ func (bc *BlockChain) SubscribeChainSideEvent(ch chan<- ChainSideEvent) event.Su
 func (bc *BlockChain) SubscribeLogsEvent(ch chan<- []*types.Log) event.Subscription {
 	return bc.scope.Track(bc.logsFeed.Subscribe(ch))
 }
+
+// SubscribeBlockProcessingEvent registers a subscription of bool where true means
+// block processing has started while false means it has stopped.
+func (bc *BlockChain) SubscribeBlockProcessingEvent(ch chan<- bool) event.Subscription {
+	return bc.scope.Track(bc.blockProcFeed.Subscribe(ch))
+}
diff --git a/eth/backend.go b/eth/backend.go
index 6710e4513..cccb5993f 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -54,6 +54,7 @@ import (
 type LesServer interface {
 	Start(srvr *p2p.Server)
 	Stop()
+	APIs() []rpc.API
 	Protocols() []p2p.Protocol
 	SetBloomBitsIndexer(bbIndexer *core.ChainIndexer)
 }
@@ -267,6 +268,10 @@ func CreateConsensusEngine(ctx *node.ServiceContext, chainConfig *params.ChainCo
 func (s *Ethereum) APIs() []rpc.API {
 	apis := ethapi.GetAPIs(s.APIBackend)
 
+	// Append any APIs exposed explicitly by the les server
+	if s.lesServer != nil {
+		apis = append(apis, s.lesServer.APIs()...)
+	}
 	// Append any APIs exposed explicitly by the consensus engine
 	apis = append(apis, s.engine.APIs(s.BlockChain())...)
 
diff --git a/eth/config.go b/eth/config.go
index aca9b5e68..740e6825b 100644
--- a/eth/config.go
+++ b/eth/config.go
@@ -98,9 +98,11 @@ type Config struct {
 	Whitelist map[uint64]common.Hash `toml:"-"`
 
 	// Light client options
-	LightServ    int  `toml:",omitempty"` // Maximum percentage of time allowed for serving LES requests
-	LightPeers   int  `toml:",omitempty"` // Maximum number of LES client peers
-	OnlyAnnounce bool // Maximum number of LES client peers
+	LightServ         int  `toml:",omitempty"` // Maximum percentage of time allowed for serving LES requests
+	LightBandwidthIn  int  `toml:",omitempty"` // Incoming bandwidth limit for light servers
+	LightBandwidthOut int  `toml:",omitempty"` // Outgoing bandwidth limit for light servers
+	LightPeers        int  `toml:",omitempty"` // Maximum number of LES client peers
+	OnlyAnnounce      bool // Maximum number of LES client peers
 
 	// Ultra Light client options
 	ULC *ULCConfig `toml:",omitempty"`
diff --git a/eth/gen_config.go b/eth/gen_config.go
index e05b963ab..30ff8b6e1 100644
--- a/eth/gen_config.go
+++ b/eth/gen_config.go
@@ -24,6 +24,8 @@ func (c Config) MarshalTOML() (interface{}, error) {
 		SyncMode                downloader.SyncMode
 		NoPruning               bool
 		LightServ               int `toml:",omitempty"`
+		LightBandwidthIn        int `toml:",omitempty"`
+		LightBandwidthOut       int `toml:",omitempty"`
 		LightPeers              int `toml:",omitempty"`
 		OnlyAnnounce            bool
 		ULC                     *ULCConfig `toml:",omitempty"`
@@ -55,6 +57,8 @@ func (c Config) MarshalTOML() (interface{}, error) {
 	enc.SyncMode = c.SyncMode
 	enc.NoPruning = c.NoPruning
 	enc.LightServ = c.LightServ
+	enc.LightBandwidthIn = c.LightBandwidthIn
+	enc.LightBandwidthOut = c.LightBandwidthOut
 	enc.LightPeers = c.LightPeers
 	enc.OnlyAnnounce = c.OnlyAnnounce
 	enc.ULC = c.ULC
@@ -91,6 +95,8 @@ func (c *Config) UnmarshalTOML(unmarshal func(interface{}) error) error {
 		SyncMode                *downloader.SyncMode
 		NoPruning               *bool
 		LightServ               *int `toml:",omitempty"`
+		LightBandwidthIn        *int `toml:",omitempty"`
+		LightBandwidthOut       *int `toml:",omitempty"`
 		LightPeers              *int `toml:",omitempty"`
 		OnlyAnnounce            *bool
 		ULC                     *ULCConfig `toml:",omitempty"`
@@ -135,6 +141,12 @@ func (c *Config) UnmarshalTOML(unmarshal func(interface{}) error) error {
 	if dec.LightServ != nil {
 		c.LightServ = *dec.LightServ
 	}
+	if dec.LightBandwidthIn != nil {
+		c.LightBandwidthIn = *dec.LightBandwidthIn
+	}
+	if dec.LightBandwidthOut != nil {
+		c.LightBandwidthOut = *dec.LightBandwidthOut
+	}
 	if dec.LightPeers != nil {
 		c.LightPeers = *dec.LightPeers
 	}
diff --git a/les/api.go b/les/api.go
new file mode 100644
index 000000000..a933cbd06
--- /dev/null
+++ b/les/api.go
@@ -0,0 +1,454 @@
+// Copyright 2018 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"context"
+	"errors"
+	"sync"
+	"time"
+
+	"github.com/ethereum/go-ethereum/common/hexutil"
+	"github.com/ethereum/go-ethereum/common/mclock"
+	"github.com/ethereum/go-ethereum/p2p/enode"
+	"github.com/ethereum/go-ethereum/rpc"
+)
+
+var (
+	ErrMinCap               = errors.New("capacity too small")
+	ErrTotalCap             = errors.New("total capacity exceeded")
+	ErrUnknownBenchmarkType = errors.New("unknown benchmark type")
+
+	dropCapacityDelay = time.Second // delay applied to decreasing capacity changes
+)
+
+// PrivateLightServerAPI provides an API to access the LES light server.
+// It offers only methods that operate on public data that is freely available to anyone.
+type PrivateLightServerAPI struct {
+	server *LesServer
+}
+
+// NewPrivateLightServerAPI creates a new LES light server API.
+func NewPrivateLightServerAPI(server *LesServer) *PrivateLightServerAPI {
+	return &PrivateLightServerAPI{
+		server: server,
+	}
+}
+
+// TotalCapacity queries total available capacity for all clients
+func (api *PrivateLightServerAPI) TotalCapacity() hexutil.Uint64 {
+	return hexutil.Uint64(api.server.priorityClientPool.totalCapacity())
+}
+
+// SubscribeTotalCapacity subscribes to changed total capacity events.
+// If onlyUnderrun is true then notification is sent only if the total capacity
+// drops under the total capacity of connected priority clients.
+//
+// Note: actually applying decreasing total capacity values is delayed while the
+// notification is sent instantly. This allows lowering the capacity of a priority client
+// or choosing which one to drop before the system drops some of them automatically.
+func (api *PrivateLightServerAPI) SubscribeTotalCapacity(ctx context.Context, onlyUnderrun bool) (*rpc.Subscription, error) {
+	notifier, supported := rpc.NotifierFromContext(ctx)
+	if !supported {
+		return &rpc.Subscription{}, rpc.ErrNotificationsUnsupported
+	}
+	rpcSub := notifier.CreateSubscription()
+	api.server.priorityClientPool.subscribeTotalCapacity(&tcSubscription{notifier, rpcSub, onlyUnderrun})
+	return rpcSub, nil
+}
+
+type (
+	// tcSubscription represents a total capacity subscription
+	tcSubscription struct {
+		notifier     *rpc.Notifier
+		rpcSub       *rpc.Subscription
+		onlyUnderrun bool
+	}
+	tcSubs map[*tcSubscription]struct{}
+)
+
+// send sends a changed total capacity event to the subscribers
+func (s tcSubs) send(tc uint64, underrun bool) {
+	for sub := range s {
+		select {
+		case <-sub.rpcSub.Err():
+			delete(s, sub)
+		case <-sub.notifier.Closed():
+			delete(s, sub)
+		default:
+			if underrun || !sub.onlyUnderrun {
+				sub.notifier.Notify(sub.rpcSub.ID, tc)
+			}
+		}
+	}
+}
+
+// MinimumCapacity queries minimum assignable capacity for a single client
+func (api *PrivateLightServerAPI) MinimumCapacity() hexutil.Uint64 {
+	return hexutil.Uint64(minCapacity)
+}
+
+// FreeClientCapacity queries the capacity provided for free clients
+func (api *PrivateLightServerAPI) FreeClientCapacity() hexutil.Uint64 {
+	return hexutil.Uint64(api.server.freeClientCap)
+}
+
+// SetClientCapacity sets the priority capacity assigned to a given client.
+// If the assigned capacity is bigger than zero then connection is always
+// guaranteed. The sum of capacity assigned to priority clients can not exceed
+// the total available capacity.
+//
+// Note: assigned capacity can be changed while the client is connected with
+// immediate effect.
+func (api *PrivateLightServerAPI) SetClientCapacity(id enode.ID, cap uint64) error {
+	if cap != 0 && cap < minCapacity {
+		return ErrMinCap
+	}
+	return api.server.priorityClientPool.setClientCapacity(id, cap)
+}
+
+// GetClientCapacity returns the capacity assigned to a given client
+func (api *PrivateLightServerAPI) GetClientCapacity(id enode.ID) hexutil.Uint64 {
+	api.server.priorityClientPool.lock.Lock()
+	defer api.server.priorityClientPool.lock.Unlock()
+
+	return hexutil.Uint64(api.server.priorityClientPool.clients[id].cap)
+}
+
+// clientPool is implemented by both the free and priority client pools
+type clientPool interface {
+	peerSetNotify
+	setLimits(count int, totalCap uint64)
+}
+
+// priorityClientPool stores information about prioritized clients
+type priorityClientPool struct {
+	lock                             sync.Mutex
+	child                            clientPool
+	ps                               *peerSet
+	clients                          map[enode.ID]priorityClientInfo
+	totalCap, totalCapAnnounced      uint64
+	totalConnectedCap, freeClientCap uint64
+	maxPeers, priorityCount          int
+
+	subs            tcSubs
+	updateSchedule  []scheduledUpdate
+	scheduleCounter uint64
+}
+
+// scheduledUpdate represents a delayed total capacity update
+type scheduledUpdate struct {
+	time         mclock.AbsTime
+	totalCap, id uint64
+}
+
+// priorityClientInfo entries exist for all prioritized clients and currently connected non-priority clients
+type priorityClientInfo struct {
+	cap       uint64 // zero for non-priority clients
+	connected bool
+	peer      *peer
+}
+
+// newPriorityClientPool creates a new priority client pool
+func newPriorityClientPool(freeClientCap uint64, ps *peerSet, child clientPool) *priorityClientPool {
+	return &priorityClientPool{
+		clients:       make(map[enode.ID]priorityClientInfo),
+		freeClientCap: freeClientCap,
+		ps:            ps,
+		child:         child,
+	}
+}
+
+// registerPeer is called when a new client is connected. If the client has no
+// priority assigned then it is passed to the child pool which may either keep it
+// or disconnect it.
+//
+// Note: priorityClientPool also stores a record about free clients while they are
+// connected in order to be able to assign priority to them later.
+func (v *priorityClientPool) registerPeer(p *peer) {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	id := p.ID()
+	c := v.clients[id]
+	if c.connected {
+		return
+	}
+	if c.cap == 0 && v.child != nil {
+		v.child.registerPeer(p)
+	}
+	if c.cap != 0 && v.totalConnectedCap+c.cap > v.totalCap {
+		go v.ps.Unregister(p.id)
+		return
+	}
+
+	c.connected = true
+	c.peer = p
+	v.clients[id] = c
+	if c.cap != 0 {
+		v.priorityCount++
+		v.totalConnectedCap += c.cap
+		if v.child != nil {
+			v.child.setLimits(v.maxPeers-v.priorityCount, v.totalCap-v.totalConnectedCap)
+		}
+		p.updateCapacity(c.cap)
+	}
+}
+
+// unregisterPeer is called when a client is disconnected. If the client has no
+// priority assigned then it is also removed from the child pool.
+func (v *priorityClientPool) unregisterPeer(p *peer) {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	id := p.ID()
+	c := v.clients[id]
+	if !c.connected {
+		return
+	}
+	if c.cap != 0 {
+		c.connected = false
+		v.clients[id] = c
+		v.priorityCount--
+		v.totalConnectedCap -= c.cap
+		if v.child != nil {
+			v.child.setLimits(v.maxPeers-v.priorityCount, v.totalCap-v.totalConnectedCap)
+		}
+	} else {
+		if v.child != nil {
+			v.child.unregisterPeer(p)
+		}
+		delete(v.clients, id)
+	}
+}
+
+// setLimits updates the allowed peer count and total capacity of the priority
+// client pool. Since the free client pool is a child of the priority pool the
+// remaining peer count and capacity is assigned to the free pool by calling its
+// own setLimits function.
+//
+// Note: a decreasing change of the total capacity is applied with a delay.
+func (v *priorityClientPool) setLimits(count int, totalCap uint64) {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	v.totalCapAnnounced = totalCap
+	if totalCap > v.totalCap {
+		v.setLimitsNow(count, totalCap)
+		v.subs.send(totalCap, false)
+		return
+	}
+	v.setLimitsNow(count, v.totalCap)
+	if totalCap < v.totalCap {
+		v.subs.send(totalCap, totalCap < v.totalConnectedCap)
+		for i, s := range v.updateSchedule {
+			if totalCap >= s.totalCap {
+				s.totalCap = totalCap
+				v.updateSchedule = v.updateSchedule[:i+1]
+				return
+			}
+		}
+		v.updateSchedule = append(v.updateSchedule, scheduledUpdate{time: mclock.Now() + mclock.AbsTime(dropCapacityDelay), totalCap: totalCap})
+		if len(v.updateSchedule) == 1 {
+			v.scheduleCounter++
+			id := v.scheduleCounter
+			v.updateSchedule[0].id = id
+			time.AfterFunc(dropCapacityDelay, func() { v.checkUpdate(id) })
+		}
+	} else {
+		v.updateSchedule = nil
+	}
+}
+
+// checkUpdate performs the next scheduled update if possible and schedules
+// the one after that
+func (v *priorityClientPool) checkUpdate(id uint64) {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	if len(v.updateSchedule) == 0 || v.updateSchedule[0].id != id {
+		return
+	}
+	v.setLimitsNow(v.maxPeers, v.updateSchedule[0].totalCap)
+	v.updateSchedule = v.updateSchedule[1:]
+	if len(v.updateSchedule) != 0 {
+		v.scheduleCounter++
+		id := v.scheduleCounter
+		v.updateSchedule[0].id = id
+		dt := time.Duration(v.updateSchedule[0].time - mclock.Now())
+		time.AfterFunc(dt, func() { v.checkUpdate(id) })
+	}
+}
+
+// setLimits updates the allowed peer count and total capacity immediately
+func (v *priorityClientPool) setLimitsNow(count int, totalCap uint64) {
+	if v.priorityCount > count || v.totalConnectedCap > totalCap {
+		for id, c := range v.clients {
+			if c.connected {
+				c.connected = false
+				v.totalConnectedCap -= c.cap
+				v.priorityCount--
+				v.clients[id] = c
+				go v.ps.Unregister(c.peer.id)
+				if v.priorityCount <= count && v.totalConnectedCap <= totalCap {
+					break
+				}
+			}
+		}
+	}
+	v.maxPeers = count
+	v.totalCap = totalCap
+	if v.child != nil {
+		v.child.setLimits(v.maxPeers-v.priorityCount, v.totalCap-v.totalConnectedCap)
+	}
+}
+
+// totalCapacity queries total available capacity for all clients
+func (v *priorityClientPool) totalCapacity() uint64 {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	return v.totalCapAnnounced
+}
+
+// subscribeTotalCapacity subscribes to changed total capacity events
+func (v *priorityClientPool) subscribeTotalCapacity(sub *tcSubscription) {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	v.subs[sub] = struct{}{}
+}
+
+// setClientCapacity sets the priority capacity assigned to a given client
+func (v *priorityClientPool) setClientCapacity(id enode.ID, cap uint64) error {
+	v.lock.Lock()
+	defer v.lock.Unlock()
+
+	c := v.clients[id]
+	if c.cap == cap {
+		return nil
+	}
+	if c.connected {
+		if v.totalConnectedCap+cap > v.totalCap+c.cap {
+			return ErrTotalCap
+		}
+		if c.cap == 0 {
+			if v.child != nil {
+				v.child.unregisterPeer(c.peer)
+			}
+			v.priorityCount++
+		}
+		if cap == 0 {
+			v.priorityCount--
+		}
+		v.totalConnectedCap += cap - c.cap
+		if v.child != nil {
+			v.child.setLimits(v.maxPeers-v.priorityCount, v.totalCap-v.totalConnectedCap)
+		}
+		if cap == 0 {
+			if v.child != nil {
+				v.child.registerPeer(c.peer)
+			}
+			c.peer.updateCapacity(v.freeClientCap)
+		} else {
+			c.peer.updateCapacity(cap)
+		}
+	}
+	if cap != 0 || c.connected {
+		c.cap = cap
+		v.clients[id] = c
+	} else {
+		delete(v.clients, id)
+	}
+	return nil
+}
+
+// Benchmark runs a request performance benchmark with a given set of measurement setups
+// in multiple passes specified by passCount. The measurement time for each setup in each
+// pass is specified in milliseconds by length.
+//
+// Note: measurement time is adjusted for each pass depending on the previous ones.
+// Therefore a controlled total measurement time is achievable in multiple passes.
+func (api *PrivateLightServerAPI) Benchmark(setups []map[string]interface{}, passCount, length int) ([]map[string]interface{}, error) {
+	benchmarks := make([]requestBenchmark, len(setups))
+	for i, setup := range setups {
+		if t, ok := setup["type"].(string); ok {
+			getInt := func(field string, def int) int {
+				if value, ok := setup[field].(float64); ok {
+					return int(value)
+				}
+				return def
+			}
+			getBool := func(field string, def bool) bool {
+				if value, ok := setup[field].(bool); ok {
+					return value
+				}
+				return def
+			}
+			switch t {
+			case "header":
+				benchmarks[i] = &benchmarkBlockHeaders{
+					amount:  getInt("amount", 1),
+					skip:    getInt("skip", 1),
+					byHash:  getBool("byHash", false),
+					reverse: getBool("reverse", false),
+				}
+			case "body":
+				benchmarks[i] = &benchmarkBodiesOrReceipts{receipts: false}
+			case "receipts":
+				benchmarks[i] = &benchmarkBodiesOrReceipts{receipts: true}
+			case "proof":
+				benchmarks[i] = &benchmarkProofsOrCode{code: false}
+			case "code":
+				benchmarks[i] = &benchmarkProofsOrCode{code: true}
+			case "cht":
+				benchmarks[i] = &benchmarkHelperTrie{
+					bloom:    false,
+					reqCount: getInt("amount", 1),
+				}
+			case "bloom":
+				benchmarks[i] = &benchmarkHelperTrie{
+					bloom:    true,
+					reqCount: getInt("amount", 1),
+				}
+			case "txSend":
+				benchmarks[i] = &benchmarkTxSend{}
+			case "txStatus":
+				benchmarks[i] = &benchmarkTxStatus{}
+			default:
+				return nil, ErrUnknownBenchmarkType
+			}
+		} else {
+			return nil, ErrUnknownBenchmarkType
+		}
+	}
+	rs := api.server.protocolManager.runBenchmark(benchmarks, passCount, time.Millisecond*time.Duration(length))
+	result := make([]map[string]interface{}, len(setups))
+	for i, r := range rs {
+		res := make(map[string]interface{})
+		if r.err == nil {
+			res["totalCount"] = r.totalCount
+			res["avgTime"] = r.avgTime
+			res["maxInSize"] = r.maxInSize
+			res["maxOutSize"] = r.maxOutSize
+		} else {
+			res["error"] = r.err.Error()
+		}
+		result[i] = res
+	}
+	return result, nil
+}
diff --git a/les/api_test.go b/les/api_test.go
new file mode 100644
index 000000000..cec945962
--- /dev/null
+++ b/les/api_test.go
@@ -0,0 +1,525 @@
+// Copyright 2016 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"context"
+	"errors"
+	"flag"
+	"fmt"
+	"io/ioutil"
+	"math/rand"
+	"os"
+	"sync"
+	"sync/atomic"
+	"testing"
+	"time"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/hexutil"
+	"github.com/ethereum/go-ethereum/consensus/ethash"
+	"github.com/ethereum/go-ethereum/eth"
+	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/les/flowcontrol"
+	"github.com/ethereum/go-ethereum/log"
+	"github.com/ethereum/go-ethereum/node"
+	"github.com/ethereum/go-ethereum/p2p/enode"
+	"github.com/ethereum/go-ethereum/p2p/simulations"
+	"github.com/ethereum/go-ethereum/p2p/simulations/adapters"
+	"github.com/ethereum/go-ethereum/rpc"
+	colorable "github.com/mattn/go-colorable"
+)
+
+/*
+This test is not meant to be a part of the automatic testing process because it
+runs for a long time and also requires a large database in order to do a meaningful
+request performance test. When testServerDataDir is empty, the test is skipped.
+*/
+
+const (
+	testServerDataDir  = "" // should always be empty on the master branch
+	testServerCapacity = 200
+	testMaxClients     = 10
+	testTolerance      = 0.1
+	minRelCap          = 0.2
+)
+
+func TestCapacityAPI3(t *testing.T) {
+	testCapacityAPI(t, 3)
+}
+
+func TestCapacityAPI6(t *testing.T) {
+	testCapacityAPI(t, 6)
+}
+
+func TestCapacityAPI10(t *testing.T) {
+	testCapacityAPI(t, 10)
+}
+
+// testCapacityAPI runs an end-to-end simulation test connecting one server with
+// a given number of clients. It sets different priority capacities to all clients
+// except a randomly selected one which runs in free client mode. All clients send
+// similar requests at the maximum allowed rate and the test verifies whether the
+// ratio of processed requests is close enough to the ratio of assigned capacities.
+// Running multiple rounds with different settings ensures that changing capacity
+// while connected and going back and forth between free and priority mode with
+// the supplied API calls is also thoroughly tested.
+func testCapacityAPI(t *testing.T, clientCount int) {
+	if testServerDataDir == "" {
+		// Skip test if no data dir specified
+		return
+	}
+
+	for !testSim(t, 1, clientCount, []string{testServerDataDir}, nil, func(ctx context.Context, net *simulations.Network, servers []*simulations.Node, clients []*simulations.Node) bool {
+		if len(servers) != 1 {
+			t.Fatalf("Invalid number of servers: %d", len(servers))
+		}
+		server := servers[0]
+
+		clientRpcClients := make([]*rpc.Client, len(clients))
+
+		serverRpcClient, err := server.Client()
+		if err != nil {
+			t.Fatalf("Failed to obtain rpc client: %v", err)
+		}
+		headNum, headHash := getHead(ctx, t, serverRpcClient)
+		totalCap := getTotalCap(ctx, t, serverRpcClient)
+		minCap := getMinCap(ctx, t, serverRpcClient)
+		testCap := totalCap * 3 / 4
+		fmt.Printf("Server testCap: %d  minCap: %d  head number: %d  head hash: %064x\n", testCap, minCap, headNum, headHash)
+		reqMinCap := uint64(float64(testCap) * minRelCap / (minRelCap + float64(len(clients)-1)))
+		if minCap > reqMinCap {
+			t.Fatalf("Minimum client capacity (%d) bigger than required minimum for this test (%d)", minCap, reqMinCap)
+		}
+
+		freeIdx := rand.Intn(len(clients))
+		freeCap := getFreeCap(ctx, t, serverRpcClient)
+
+		for i, client := range clients {
+			var err error
+			clientRpcClients[i], err = client.Client()
+			if err != nil {
+				t.Fatalf("Failed to obtain rpc client: %v", err)
+			}
+
+			fmt.Println("connecting client", i)
+			if i != freeIdx {
+				setCapacity(ctx, t, serverRpcClient, client.ID(), testCap/uint64(len(clients)))
+			}
+			net.Connect(client.ID(), server.ID())
+
+			for {
+				select {
+				case <-ctx.Done():
+					t.Fatalf("Timeout")
+				default:
+				}
+				num, hash := getHead(ctx, t, clientRpcClients[i])
+				if num == headNum && hash == headHash {
+					fmt.Println("client", i, "synced")
+					break
+				}
+				time.Sleep(time.Millisecond * 200)
+			}
+		}
+
+		var wg sync.WaitGroup
+		stop := make(chan struct{})
+
+		reqCount := make([]uint64, len(clientRpcClients))
+
+		for i, c := range clientRpcClients {
+			wg.Add(1)
+			i, c := i, c
+			go func() {
+				queue := make(chan struct{}, 100)
+				var count uint64
+				for {
+					select {
+					case queue <- struct{}{}:
+						select {
+						case <-stop:
+							wg.Done()
+							return
+						case <-ctx.Done():
+							wg.Done()
+							return
+						default:
+							wg.Add(1)
+							go func() {
+								ok := testRequest(ctx, t, c)
+								wg.Done()
+								<-queue
+								if ok {
+									count++
+									atomic.StoreUint64(&reqCount[i], count)
+								}
+							}()
+						}
+					case <-stop:
+						wg.Done()
+						return
+					case <-ctx.Done():
+						wg.Done()
+						return
+					}
+				}
+			}()
+		}
+
+		processedSince := func(start []uint64) []uint64 {
+			res := make([]uint64, len(reqCount))
+			for i := range reqCount {
+				res[i] = atomic.LoadUint64(&reqCount[i])
+				if start != nil {
+					res[i] -= start[i]
+				}
+			}
+			return res
+		}
+
+		weights := make([]float64, len(clients))
+		for c := 0; c < 5; c++ {
+			setCapacity(ctx, t, serverRpcClient, clients[freeIdx].ID(), freeCap)
+			freeIdx = rand.Intn(len(clients))
+			var sum float64
+			for i := range clients {
+				if i == freeIdx {
+					weights[i] = 0
+				} else {
+					weights[i] = rand.Float64()*(1-minRelCap) + minRelCap
+				}
+				sum += weights[i]
+			}
+			for i, client := range clients {
+				weights[i] *= float64(testCap-freeCap-100) / sum
+				capacity := uint64(weights[i])
+				if i != freeIdx && capacity < getCapacity(ctx, t, serverRpcClient, client.ID()) {
+					setCapacity(ctx, t, serverRpcClient, client.ID(), capacity)
+				}
+			}
+			setCapacity(ctx, t, serverRpcClient, clients[freeIdx].ID(), 0)
+			for i, client := range clients {
+				capacity := uint64(weights[i])
+				if i != freeIdx && capacity > getCapacity(ctx, t, serverRpcClient, client.ID()) {
+					setCapacity(ctx, t, serverRpcClient, client.ID(), capacity)
+				}
+			}
+			weights[freeIdx] = float64(freeCap)
+			for i := range clients {
+				weights[i] /= float64(testCap)
+			}
+
+			time.Sleep(flowcontrol.DecParamDelay)
+			fmt.Println("Starting measurement")
+			fmt.Printf("Relative weights:")
+			for i := range clients {
+				fmt.Printf("  %f", weights[i])
+			}
+			fmt.Println()
+			start := processedSince(nil)
+			for {
+				select {
+				case <-ctx.Done():
+					t.Fatalf("Timeout")
+				default:
+				}
+
+				totalCap = getTotalCap(ctx, t, serverRpcClient)
+				if totalCap < testCap {
+					fmt.Println("Total capacity underrun")
+					close(stop)
+					wg.Wait()
+					return false
+				}
+
+				processed := processedSince(start)
+				var avg uint64
+				fmt.Printf("Processed")
+				for i, p := range processed {
+					fmt.Printf(" %d", p)
+					processed[i] = uint64(float64(p) / weights[i])
+					avg += processed[i]
+				}
+				avg /= uint64(len(processed))
+
+				if avg >= 10000 {
+					var maxDev float64
+					for _, p := range processed {
+						dev := float64(int64(p-avg)) / float64(avg)
+						fmt.Printf(" %7.4f", dev)
+						if dev < 0 {
+							dev = -dev
+						}
+						if dev > maxDev {
+							maxDev = dev
+						}
+					}
+					fmt.Printf("  max deviation: %f  totalCap: %d\n", maxDev, totalCap)
+					if maxDev <= testTolerance {
+						fmt.Println("success")
+						break
+					}
+				} else {
+					fmt.Println()
+				}
+				time.Sleep(time.Millisecond * 200)
+			}
+		}
+
+		close(stop)
+		wg.Wait()
+
+		for i, count := range reqCount {
+			fmt.Println("client", i, "processed", count)
+		}
+		return true
+	}) {
+		fmt.Println("restarting test")
+	}
+}
+
+func getHead(ctx context.Context, t *testing.T, client *rpc.Client) (uint64, common.Hash) {
+	res := make(map[string]interface{})
+	if err := client.CallContext(ctx, &res, "eth_getBlockByNumber", "latest", false); err != nil {
+		t.Fatalf("Failed to obtain head block: %v", err)
+	}
+	numStr, ok := res["number"].(string)
+	if !ok {
+		t.Fatalf("RPC block number field invalid")
+	}
+	num, err := hexutil.DecodeUint64(numStr)
+	if err != nil {
+		t.Fatalf("Failed to decode RPC block number: %v", err)
+	}
+	hashStr, ok := res["hash"].(string)
+	if !ok {
+		t.Fatalf("RPC block number field invalid")
+	}
+	hash := common.HexToHash(hashStr)
+	return num, hash
+}
+
+func testRequest(ctx context.Context, t *testing.T, client *rpc.Client) bool {
+	//res := make(map[string]interface{})
+	var res string
+	var addr common.Address
+	rand.Read(addr[:])
+	c, _ := context.WithTimeout(ctx, time.Second*12)
+	//	if err := client.CallContext(ctx, &res, "eth_getProof", addr, nil, "latest"); err != nil {
+	err := client.CallContext(c, &res, "eth_getBalance", addr, "latest")
+	if err != nil {
+		fmt.Println("request error:", err)
+	}
+	return err == nil
+}
+
+func setCapacity(ctx context.Context, t *testing.T, server *rpc.Client, clientID enode.ID, cap uint64) {
+	if err := server.CallContext(ctx, nil, "les_setClientCapacity", clientID, cap); err != nil {
+		t.Fatalf("Failed to set client capacity: %v", err)
+	}
+}
+
+func getCapacity(ctx context.Context, t *testing.T, server *rpc.Client, clientID enode.ID) uint64 {
+	var s string
+	if err := server.CallContext(ctx, &s, "les_getClientCapacity", clientID); err != nil {
+		t.Fatalf("Failed to get client capacity: %v", err)
+	}
+	cap, err := hexutil.DecodeUint64(s)
+	if err != nil {
+		t.Fatalf("Failed to decode client capacity: %v", err)
+	}
+	return cap
+}
+
+func getTotalCap(ctx context.Context, t *testing.T, server *rpc.Client) uint64 {
+	var s string
+	if err := server.CallContext(ctx, &s, "les_totalCapacity"); err != nil {
+		t.Fatalf("Failed to query total capacity: %v", err)
+	}
+	total, err := hexutil.DecodeUint64(s)
+	if err != nil {
+		t.Fatalf("Failed to decode total capacity: %v", err)
+	}
+	return total
+}
+
+func getMinCap(ctx context.Context, t *testing.T, server *rpc.Client) uint64 {
+	var s string
+	if err := server.CallContext(ctx, &s, "les_minimumCapacity"); err != nil {
+		t.Fatalf("Failed to query minimum capacity: %v", err)
+	}
+	min, err := hexutil.DecodeUint64(s)
+	if err != nil {
+		t.Fatalf("Failed to decode minimum capacity: %v", err)
+	}
+	return min
+}
+
+func getFreeCap(ctx context.Context, t *testing.T, server *rpc.Client) uint64 {
+	var s string
+	if err := server.CallContext(ctx, &s, "les_freeClientCapacity"); err != nil {
+		t.Fatalf("Failed to query free client capacity: %v", err)
+	}
+	free, err := hexutil.DecodeUint64(s)
+	if err != nil {
+		t.Fatalf("Failed to decode free client capacity: %v", err)
+	}
+	return free
+}
+
+func init() {
+	flag.Parse()
+	// register the Delivery service which will run as a devp2p
+	// protocol when using the exec adapter
+	adapters.RegisterServices(services)
+
+	log.PrintOrigins(true)
+	log.Root().SetHandler(log.LvlFilterHandler(log.Lvl(*loglevel), log.StreamHandler(colorable.NewColorableStderr(), log.TerminalFormat(true))))
+}
+
+var (
+	adapter  = flag.String("adapter", "exec", "type of simulation: sim|socket|exec|docker")
+	loglevel = flag.Int("loglevel", 0, "verbosity of logs")
+	nodes    = flag.Int("nodes", 0, "number of nodes")
+)
+
+var services = adapters.Services{
+	"lesclient": newLesClientService,
+	"lesserver": newLesServerService,
+}
+
+func NewNetwork() (*simulations.Network, func(), error) {
+	adapter, adapterTeardown, err := NewAdapter(*adapter, services)
+	if err != nil {
+		return nil, adapterTeardown, err
+	}
+	defaultService := "streamer"
+	net := simulations.NewNetwork(adapter, &simulations.NetworkConfig{
+		ID:             "0",
+		DefaultService: defaultService,
+	})
+	teardown := func() {
+		adapterTeardown()
+		net.Shutdown()
+	}
+
+	return net, teardown, nil
+}
+
+func NewAdapter(adapterType string, services adapters.Services) (adapter adapters.NodeAdapter, teardown func(), err error) {
+	teardown = func() {}
+	switch adapterType {
+	case "sim":
+		adapter = adapters.NewSimAdapter(services)
+		//	case "socket":
+		//		adapter = adapters.NewSocketAdapter(services)
+	case "exec":
+		baseDir, err0 := ioutil.TempDir("", "les-test")
+		if err0 != nil {
+			return nil, teardown, err0
+		}
+		teardown = func() { os.RemoveAll(baseDir) }
+		adapter = adapters.NewExecAdapter(baseDir)
+	/*case "docker":
+	adapter, err = adapters.NewDockerAdapter()
+	if err != nil {
+		return nil, teardown, err
+	}*/
+	default:
+		return nil, teardown, errors.New("adapter needs to be one of sim, socket, exec, docker")
+	}
+	return adapter, teardown, nil
+}
+
+func testSim(t *testing.T, serverCount, clientCount int, serverDir, clientDir []string, test func(ctx context.Context, net *simulations.Network, servers []*simulations.Node, clients []*simulations.Node) bool) bool {
+	net, teardown, err := NewNetwork()
+	defer teardown()
+	if err != nil {
+		t.Fatalf("Failed to create network: %v", err)
+	}
+	timeout := 1800 * time.Second
+	ctx, cancel := context.WithTimeout(context.Background(), timeout)
+	defer cancel()
+
+	servers := make([]*simulations.Node, serverCount)
+	clients := make([]*simulations.Node, clientCount)
+
+	for i := range clients {
+		clientconf := adapters.RandomNodeConfig()
+		clientconf.Services = []string{"lesclient"}
+		if len(clientDir) == clientCount {
+			clientconf.DataDir = clientDir[i]
+		}
+		client, err := net.NewNodeWithConfig(clientconf)
+		if err != nil {
+			t.Fatalf("Failed to create client: %v", err)
+		}
+		clients[i] = client
+	}
+
+	for i := range servers {
+		serverconf := adapters.RandomNodeConfig()
+		serverconf.Services = []string{"lesserver"}
+		if len(serverDir) == serverCount {
+			serverconf.DataDir = serverDir[i]
+		}
+		server, err := net.NewNodeWithConfig(serverconf)
+		if err != nil {
+			t.Fatalf("Failed to create server: %v", err)
+		}
+		servers[i] = server
+	}
+
+	for _, client := range clients {
+		if err := net.Start(client.ID()); err != nil {
+			t.Fatalf("Failed to start client node: %v", err)
+		}
+	}
+	for _, server := range servers {
+		if err := net.Start(server.ID()); err != nil {
+			t.Fatalf("Failed to start server node: %v", err)
+		}
+	}
+
+	return test(ctx, net, servers, clients)
+}
+
+func newLesClientService(ctx *adapters.ServiceContext) (node.Service, error) {
+	config := eth.DefaultConfig
+	config.SyncMode = downloader.LightSync
+	config.Ethash.PowMode = ethash.ModeFake
+	return New(ctx.NodeContext, &config)
+}
+
+func newLesServerService(ctx *adapters.ServiceContext) (node.Service, error) {
+	config := eth.DefaultConfig
+	config.SyncMode = downloader.FullSync
+	config.LightServ = testServerCapacity
+	config.LightPeers = testMaxClients
+	ethereum, err := eth.New(ctx.NodeContext, &config)
+	if err != nil {
+		return nil, err
+	}
+
+	server, err := NewLesServer(ethereum, &config)
+	if err != nil {
+		return nil, err
+	}
+	ethereum.AddLesServer(server)
+	return ethereum, nil
+}
diff --git a/les/backend.go b/les/backend.go
index cd99f8f81..67ddf17e4 100644
--- a/les/backend.go
+++ b/les/backend.go
@@ -25,6 +25,7 @@ import (
 	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/common/hexutil"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/bloombits"
@@ -100,7 +101,7 @@ func New(ctx *node.ServiceContext, config *eth.Config) (*LightEthereum, error) {
 		chainConfig:    chainConfig,
 		eventMux:       ctx.EventMux,
 		peers:          peers,
-		reqDist:        newRequestDistributor(peers, quitSync),
+		reqDist:        newRequestDistributor(peers, quitSync, &mclock.System{}),
 		accountManager: ctx.AccountManager,
 		engine:         eth.CreateConsensusEngine(ctx, chainConfig, &config.Ethash, nil, false, chainDb),
 		shutdownChan:   make(chan bool),
diff --git a/les/benchmark.go b/les/benchmark.go
new file mode 100644
index 000000000..cb302c6ea
--- /dev/null
+++ b/les/benchmark.go
@@ -0,0 +1,353 @@
+// Copyright 2018 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"encoding/binary"
+	"fmt"
+	"math/big"
+	"math/rand"
+	"time"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
+	"github.com/ethereum/go-ethereum/core/rawdb"
+	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/les/flowcontrol"
+	"github.com/ethereum/go-ethereum/log"
+	"github.com/ethereum/go-ethereum/p2p"
+	"github.com/ethereum/go-ethereum/p2p/enode"
+	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
+)
+
+// requestBenchmark is an interface for different randomized request generators
+type requestBenchmark interface {
+	// init initializes the generator for generating the given number of randomized requests
+	init(pm *ProtocolManager, count int) error
+	// request initiates sending a single request to the given peer
+	request(peer *peer, index int) error
+}
+
+// benchmarkBlockHeaders implements requestBenchmark
+type benchmarkBlockHeaders struct {
+	amount, skip    int
+	reverse, byHash bool
+	offset, randMax int64
+	hashes          []common.Hash
+}
+
+func (b *benchmarkBlockHeaders) init(pm *ProtocolManager, count int) error {
+	d := int64(b.amount-1) * int64(b.skip+1)
+	b.offset = 0
+	b.randMax = pm.blockchain.CurrentHeader().Number.Int64() + 1 - d
+	if b.randMax < 0 {
+		return fmt.Errorf("chain is too short")
+	}
+	if b.reverse {
+		b.offset = d
+	}
+	if b.byHash {
+		b.hashes = make([]common.Hash, count)
+		for i := range b.hashes {
+			b.hashes[i] = rawdb.ReadCanonicalHash(pm.chainDb, uint64(b.offset+rand.Int63n(b.randMax)))
+		}
+	}
+	return nil
+}
+
+func (b *benchmarkBlockHeaders) request(peer *peer, index int) error {
+	if b.byHash {
+		return peer.RequestHeadersByHash(0, 0, b.hashes[index], b.amount, b.skip, b.reverse)
+	} else {
+		return peer.RequestHeadersByNumber(0, 0, uint64(b.offset+rand.Int63n(b.randMax)), b.amount, b.skip, b.reverse)
+	}
+}
+
+// benchmarkBodiesOrReceipts implements requestBenchmark
+type benchmarkBodiesOrReceipts struct {
+	receipts bool
+	hashes   []common.Hash
+}
+
+func (b *benchmarkBodiesOrReceipts) init(pm *ProtocolManager, count int) error {
+	randMax := pm.blockchain.CurrentHeader().Number.Int64() + 1
+	b.hashes = make([]common.Hash, count)
+	for i := range b.hashes {
+		b.hashes[i] = rawdb.ReadCanonicalHash(pm.chainDb, uint64(rand.Int63n(randMax)))
+	}
+	return nil
+}
+
+func (b *benchmarkBodiesOrReceipts) request(peer *peer, index int) error {
+	if b.receipts {
+		return peer.RequestReceipts(0, 0, []common.Hash{b.hashes[index]})
+	} else {
+		return peer.RequestBodies(0, 0, []common.Hash{b.hashes[index]})
+	}
+}
+
+// benchmarkProofsOrCode implements requestBenchmark
+type benchmarkProofsOrCode struct {
+	code     bool
+	headHash common.Hash
+}
+
+func (b *benchmarkProofsOrCode) init(pm *ProtocolManager, count int) error {
+	b.headHash = pm.blockchain.CurrentHeader().Hash()
+	return nil
+}
+
+func (b *benchmarkProofsOrCode) request(peer *peer, index int) error {
+	key := make([]byte, 32)
+	rand.Read(key)
+	if b.code {
+		return peer.RequestCode(0, 0, []CodeReq{{BHash: b.headHash, AccKey: key}})
+	} else {
+		return peer.RequestProofs(0, 0, []ProofReq{{BHash: b.headHash, Key: key}})
+	}
+}
+
+// benchmarkHelperTrie implements requestBenchmark
+type benchmarkHelperTrie struct {
+	bloom                 bool
+	reqCount              int
+	sectionCount, headNum uint64
+}
+
+func (b *benchmarkHelperTrie) init(pm *ProtocolManager, count int) error {
+	if b.bloom {
+		b.sectionCount, b.headNum, _ = pm.server.bloomTrieIndexer.Sections()
+	} else {
+		b.sectionCount, _, _ = pm.server.chtIndexer.Sections()
+		b.sectionCount /= (params.CHTFrequencyClient / params.CHTFrequencyServer)
+		b.headNum = b.sectionCount*params.CHTFrequencyClient - 1
+	}
+	if b.sectionCount == 0 {
+		return fmt.Errorf("no processed sections available")
+	}
+	return nil
+}
+
+func (b *benchmarkHelperTrie) request(peer *peer, index int) error {
+	reqs := make([]HelperTrieReq, b.reqCount)
+
+	if b.bloom {
+		bitIdx := uint16(rand.Intn(2048))
+		for i := range reqs {
+			key := make([]byte, 10)
+			binary.BigEndian.PutUint16(key[:2], bitIdx)
+			binary.BigEndian.PutUint64(key[2:], uint64(rand.Int63n(int64(b.sectionCount))))
+			reqs[i] = HelperTrieReq{Type: htBloomBits, TrieIdx: b.sectionCount - 1, Key: key}
+		}
+	} else {
+		for i := range reqs {
+			key := make([]byte, 8)
+			binary.BigEndian.PutUint64(key[:], uint64(rand.Int63n(int64(b.headNum))))
+			reqs[i] = HelperTrieReq{Type: htCanonical, TrieIdx: b.sectionCount - 1, Key: key, AuxReq: auxHeader}
+		}
+	}
+
+	return peer.RequestHelperTrieProofs(0, 0, reqs)
+}
+
+// benchmarkTxSend implements requestBenchmark
+type benchmarkTxSend struct {
+	txs types.Transactions
+}
+
+func (b *benchmarkTxSend) init(pm *ProtocolManager, count int) error {
+	key, _ := crypto.GenerateKey()
+	addr := crypto.PubkeyToAddress(key.PublicKey)
+	signer := types.NewEIP155Signer(big.NewInt(18))
+	b.txs = make(types.Transactions, count)
+
+	for i := range b.txs {
+		data := make([]byte, txSizeCostLimit)
+		rand.Read(data)
+		tx, err := types.SignTx(types.NewTransaction(0, addr, new(big.Int), 0, new(big.Int), data), signer, key)
+		if err != nil {
+			panic(err)
+		}
+		b.txs[i] = tx
+	}
+	return nil
+}
+
+func (b *benchmarkTxSend) request(peer *peer, index int) error {
+	enc, _ := rlp.EncodeToBytes(types.Transactions{b.txs[index]})
+	return peer.SendTxs(0, 0, enc)
+}
+
+// benchmarkTxStatus implements requestBenchmark
+type benchmarkTxStatus struct{}
+
+func (b *benchmarkTxStatus) init(pm *ProtocolManager, count int) error {
+	return nil
+}
+
+func (b *benchmarkTxStatus) request(peer *peer, index int) error {
+	var hash common.Hash
+	rand.Read(hash[:])
+	return peer.RequestTxStatus(0, 0, []common.Hash{hash})
+}
+
+// benchmarkSetup stores measurement data for a single benchmark type
+type benchmarkSetup struct {
+	req                   requestBenchmark
+	totalCount            int
+	totalTime, avgTime    time.Duration
+	maxInSize, maxOutSize uint32
+	err                   error
+}
+
+// runBenchmark runs a benchmark cycle for all benchmark types in the specified
+// number of passes
+func (pm *ProtocolManager) runBenchmark(benchmarks []requestBenchmark, passCount int, targetTime time.Duration) []*benchmarkSetup {
+	setup := make([]*benchmarkSetup, len(benchmarks))
+	for i, b := range benchmarks {
+		setup[i] = &benchmarkSetup{req: b}
+	}
+	for i := 0; i < passCount; i++ {
+		log.Info("Running benchmark", "pass", i+1, "total", passCount)
+		todo := make([]*benchmarkSetup, len(benchmarks))
+		copy(todo, setup)
+		for len(todo) > 0 {
+			// select a random element
+			index := rand.Intn(len(todo))
+			next := todo[index]
+			todo[index] = todo[len(todo)-1]
+			todo = todo[:len(todo)-1]
+
+			if next.err == nil {
+				// calculate request count
+				count := 50
+				if next.totalTime > 0 {
+					count = int(uint64(next.totalCount) * uint64(targetTime) / uint64(next.totalTime))
+				}
+				if err := pm.measure(next, count); err != nil {
+					next.err = err
+				}
+			}
+		}
+	}
+	log.Info("Benchmark completed")
+
+	for _, s := range setup {
+		if s.err == nil {
+			s.avgTime = s.totalTime / time.Duration(s.totalCount)
+		}
+	}
+	return setup
+}
+
+// meteredPipe implements p2p.MsgReadWriter and remembers the largest single
+// message size sent through the pipe
+type meteredPipe struct {
+	rw      p2p.MsgReadWriter
+	maxSize uint32
+}
+
+func (m *meteredPipe) ReadMsg() (p2p.Msg, error) {
+	return m.rw.ReadMsg()
+}
+
+func (m *meteredPipe) WriteMsg(msg p2p.Msg) error {
+	if msg.Size > m.maxSize {
+		m.maxSize = msg.Size
+	}
+	return m.rw.WriteMsg(msg)
+}
+
+// measure runs a benchmark for a single type in a single pass, with the given
+// number of requests
+func (pm *ProtocolManager) measure(setup *benchmarkSetup, count int) error {
+	clientPipe, serverPipe := p2p.MsgPipe()
+	clientMeteredPipe := &meteredPipe{rw: clientPipe}
+	serverMeteredPipe := &meteredPipe{rw: serverPipe}
+	var id enode.ID
+	rand.Read(id[:])
+	clientPeer := pm.newPeer(lpv2, NetworkId, p2p.NewPeer(id, "client", nil), clientMeteredPipe)
+	serverPeer := pm.newPeer(lpv2, NetworkId, p2p.NewPeer(id, "server", nil), serverMeteredPipe)
+	serverPeer.sendQueue = newExecQueue(count)
+	serverPeer.announceType = announceTypeNone
+	serverPeer.fcCosts = make(requestCostTable)
+	c := &requestCosts{}
+	for code := range requests {
+		serverPeer.fcCosts[code] = c
+	}
+	serverPeer.fcParams = flowcontrol.ServerParams{BufLimit: 1, MinRecharge: 1}
+	serverPeer.fcClient = flowcontrol.NewClientNode(pm.server.fcManager, serverPeer.fcParams)
+	defer serverPeer.fcClient.Disconnect()
+
+	if err := setup.req.init(pm, count); err != nil {
+		return err
+	}
+
+	errCh := make(chan error, 10)
+	start := mclock.Now()
+
+	go func() {
+		for i := 0; i < count; i++ {
+			if err := setup.req.request(clientPeer, i); err != nil {
+				errCh <- err
+				return
+			}
+		}
+	}()
+	go func() {
+		for i := 0; i < count; i++ {
+			if err := pm.handleMsg(serverPeer); err != nil {
+				errCh <- err
+				return
+			}
+		}
+	}()
+	go func() {
+		for i := 0; i < count; i++ {
+			msg, err := clientPipe.ReadMsg()
+			if err != nil {
+				errCh <- err
+				return
+			}
+			var i interface{}
+			msg.Decode(&i)
+		}
+		// at this point we can be sure that the other two
+		// goroutines finished successfully too
+		close(errCh)
+	}()
+	select {
+	case err := <-errCh:
+		if err != nil {
+			return err
+		}
+	case <-pm.quitSync:
+		clientPipe.Close()
+		serverPipe.Close()
+		return fmt.Errorf("Benchmark cancelled")
+	}
+
+	setup.totalTime += time.Duration(mclock.Now() - start)
+	setup.totalCount += count
+	setup.maxInSize = clientMeteredPipe.maxSize
+	setup.maxOutSize = serverMeteredPipe.maxSize
+	clientPipe.Close()
+	serverPipe.Close()
+	return nil
+}
diff --git a/les/costtracker.go b/les/costtracker.go
new file mode 100644
index 000000000..69531937e
--- /dev/null
+++ b/les/costtracker.go
@@ -0,0 +1,388 @@
+// Copyright 2016 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more detailct.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"encoding/binary"
+	"math"
+	"sync"
+	"sync/atomic"
+	"time"
+
+	"github.com/ethereum/go-ethereum/common/mclock"
+	"github.com/ethereum/go-ethereum/eth"
+	"github.com/ethereum/go-ethereum/ethdb"
+	"github.com/ethereum/go-ethereum/les/flowcontrol"
+	"github.com/ethereum/go-ethereum/log"
+)
+
+const makeCostStats = false // make request cost statistics during operation
+
+var (
+	// average request cost estimates based on serving time
+	reqAvgTimeCost = requestCostTable{
+		GetBlockHeadersMsg:     {150000, 30000},
+		GetBlockBodiesMsg:      {0, 700000},
+		GetReceiptsMsg:         {0, 1000000},
+		GetCodeMsg:             {0, 450000},
+		GetProofsV1Msg:         {0, 600000},
+		GetProofsV2Msg:         {0, 600000},
+		GetHeaderProofsMsg:     {0, 1000000},
+		GetHelperTrieProofsMsg: {0, 1000000},
+		SendTxMsg:              {0, 450000},
+		SendTxV2Msg:            {0, 450000},
+		GetTxStatusMsg:         {0, 250000},
+	}
+	// maximum incoming message size estimates
+	reqMaxInSize = requestCostTable{
+		GetBlockHeadersMsg:     {40, 0},
+		GetBlockBodiesMsg:      {0, 40},
+		GetReceiptsMsg:         {0, 40},
+		GetCodeMsg:             {0, 80},
+		GetProofsV1Msg:         {0, 80},
+		GetProofsV2Msg:         {0, 80},
+		GetHeaderProofsMsg:     {0, 20},
+		GetHelperTrieProofsMsg: {0, 20},
+		SendTxMsg:              {0, 66000},
+		SendTxV2Msg:            {0, 66000},
+		GetTxStatusMsg:         {0, 50},
+	}
+	// maximum outgoing message size estimates
+	reqMaxOutSize = requestCostTable{
+		GetBlockHeadersMsg:     {0, 556},
+		GetBlockBodiesMsg:      {0, 100000},
+		GetReceiptsMsg:         {0, 200000},
+		GetCodeMsg:             {0, 50000},
+		GetProofsV1Msg:         {0, 4000},
+		GetProofsV2Msg:         {0, 4000},
+		GetHeaderProofsMsg:     {0, 4000},
+		GetHelperTrieProofsMsg: {0, 4000},
+		SendTxMsg:              {0, 0},
+		SendTxV2Msg:            {0, 100},
+		GetTxStatusMsg:         {0, 100},
+	}
+	minBufLimit = uint64(50000000 * maxCostFactor)  // minimum buffer limit allowed for a client
+	minCapacity = (minBufLimit-1)/bufLimitRatio + 1 // minimum capacity allowed for a client
+)
+
+const (
+	maxCostFactor    = 2 // ratio of maximum and average cost estimates
+	gfInitWeight     = time.Second * 10
+	gfMaxWeight      = time.Hour
+	gfUsageThreshold = 0.5
+	gfUsageTC        = time.Second
+	gfDbKey          = "_globalCostFactor"
+)
+
+// costTracker is responsible for calculating costs and cost estimates on the
+// server side. It continuously updates the global cost factor which is defined
+// as the number of cost units per nanosecond of serving time in a single thread.
+// It is based on statistics collected during serving requests in high-load periods
+// and practically acts as a one-dimension request price scaling factor over the
+// pre-defined cost estimate table. Instead of scaling the cost values, the real
+// value of cost units is changed by applying the factor to the serving times. This
+// is more convenient because the changes in the cost factor can be applied immediately
+// without always notifying the clients about the changed cost tables.
+type costTracker struct {
+	db     ethdb.Database
+	stopCh chan chan struct{}
+
+	inSizeFactor, outSizeFactor float64
+	gf, utilTarget              float64
+
+	gfUpdateCh      chan gfUpdate
+	gfLock          sync.RWMutex
+	totalRechargeCh chan uint64
+
+	stats map[uint64][]uint64
+}
+
+// newCostTracker creates a cost tracker and loads the cost factor statistics from the database
+func newCostTracker(db ethdb.Database, config *eth.Config) *costTracker {
+	utilTarget := float64(config.LightServ) * flowcontrol.FixedPointMultiplier / 100
+	ct := &costTracker{
+		db:         db,
+		stopCh:     make(chan chan struct{}),
+		utilTarget: utilTarget,
+	}
+	if config.LightBandwidthIn > 0 {
+		ct.inSizeFactor = utilTarget / float64(config.LightBandwidthIn)
+	}
+	if config.LightBandwidthOut > 0 {
+		ct.outSizeFactor = utilTarget / float64(config.LightBandwidthOut)
+	}
+	if makeCostStats {
+		ct.stats = make(map[uint64][]uint64)
+		for code := range reqAvgTimeCost {
+			ct.stats[code] = make([]uint64, 10)
+		}
+	}
+	ct.gfLoop()
+	return ct
+}
+
+// stop stops the cost tracker and saves the cost factor statistics to the database
+func (ct *costTracker) stop() {
+	stopCh := make(chan struct{})
+	ct.stopCh <- stopCh
+	<-stopCh
+	if makeCostStats {
+		ct.printStats()
+	}
+}
+
+// makeCostList returns upper cost estimates based on the hardcoded cost estimate
+// tables and the optionally specified incoming/outgoing bandwidth limits
+func (ct *costTracker) makeCostList() RequestCostList {
+	maxCost := func(avgTime, inSize, outSize uint64) uint64 {
+		globalFactor := ct.globalFactor()
+
+		cost := avgTime * maxCostFactor
+		inSizeCost := uint64(float64(inSize) * ct.inSizeFactor * globalFactor * maxCostFactor)
+		if inSizeCost > cost {
+			cost = inSizeCost
+		}
+		outSizeCost := uint64(float64(outSize) * ct.outSizeFactor * globalFactor * maxCostFactor)
+		if outSizeCost > cost {
+			cost = outSizeCost
+		}
+		return cost
+	}
+	var list RequestCostList
+	for code, data := range reqAvgTimeCost {
+		list = append(list, requestCostListItem{
+			MsgCode:  code,
+			BaseCost: maxCost(data.baseCost, reqMaxInSize[code].baseCost, reqMaxOutSize[code].baseCost),
+			ReqCost:  maxCost(data.reqCost, reqMaxInSize[code].reqCost, reqMaxOutSize[code].reqCost),
+		})
+	}
+	return list
+}
+
+type gfUpdate struct {
+	avgTime, servingTime float64
+}
+
+// gfLoop starts an event loop which updates the global cost factor which is
+// calculated as a weighted average of the average estimate / serving time ratio.
+// The applied weight equals the serving time if gfUsage is over a threshold,
+// zero otherwise. gfUsage is the recent average serving time per time unit in
+// an exponential moving window. This ensures that statistics are collected only
+// under high-load circumstances where the measured serving times are relevant.
+// The total recharge parameter of the flow control system which controls the
+// total allowed serving time per second but nominated in cost units, should
+// also be scaled with the cost factor and is also updated by this loop.
+func (ct *costTracker) gfLoop() {
+	var gfUsage, gfSum, gfWeight float64
+	lastUpdate := mclock.Now()
+	expUpdate := lastUpdate
+
+	data, _ := ct.db.Get([]byte(gfDbKey))
+	if len(data) == 16 {
+		gfSum = math.Float64frombits(binary.BigEndian.Uint64(data[0:8]))
+		gfWeight = math.Float64frombits(binary.BigEndian.Uint64(data[8:16]))
+	}
+	if gfWeight < float64(gfInitWeight) {
+		gfSum = float64(gfInitWeight)
+		gfWeight = float64(gfInitWeight)
+	}
+	gf := gfSum / gfWeight
+	ct.gf = gf
+	ct.gfUpdateCh = make(chan gfUpdate, 100)
+
+	go func() {
+		for {
+			select {
+			case r := <-ct.gfUpdateCh:
+				now := mclock.Now()
+				max := r.servingTime * gf
+				if r.avgTime > max {
+					max = r.avgTime
+				}
+				dt := float64(now - expUpdate)
+				expUpdate = now
+				gfUsage = gfUsage*math.Exp(-dt/float64(gfUsageTC)) + max*1000000/float64(gfUsageTC)
+
+				if gfUsage >= gfUsageThreshold*ct.utilTarget*gf {
+					gfSum += r.avgTime
+					gfWeight += r.servingTime
+					if time.Duration(now-lastUpdate) > time.Second {
+						gf = gfSum / gfWeight
+						if gfWeight >= float64(gfMaxWeight) {
+							gfSum = gf * float64(gfMaxWeight)
+							gfWeight = float64(gfMaxWeight)
+						}
+						lastUpdate = now
+						ct.gfLock.Lock()
+						ct.gf = gf
+						ch := ct.totalRechargeCh
+						ct.gfLock.Unlock()
+						if ch != nil {
+							select {
+							case ct.totalRechargeCh <- uint64(ct.utilTarget * gf):
+							default:
+							}
+						}
+						log.Debug("global cost factor updated", "gf", gf, "weight", time.Duration(gfWeight))
+					}
+				}
+			case stopCh := <-ct.stopCh:
+				var data [16]byte
+				binary.BigEndian.PutUint64(data[0:8], math.Float64bits(gfSum))
+				binary.BigEndian.PutUint64(data[8:16], math.Float64bits(gfWeight))
+				ct.db.Put([]byte(gfDbKey), data[:])
+				log.Debug("global cost factor saved", "sum", time.Duration(gfSum), "weight", time.Duration(gfWeight))
+				close(stopCh)
+				return
+			}
+		}
+	}()
+}
+
+// globalFactor returns the current value of the global cost factor
+func (ct *costTracker) globalFactor() float64 {
+	ct.gfLock.RLock()
+	defer ct.gfLock.RUnlock()
+
+	return ct.gf
+}
+
+// totalRecharge returns the current total recharge parameter which is used by
+// flowcontrol.ClientManager and is scaled by the global cost factor
+func (ct *costTracker) totalRecharge() uint64 {
+	ct.gfLock.RLock()
+	defer ct.gfLock.RUnlock()
+
+	return uint64(ct.gf * ct.utilTarget)
+}
+
+// subscribeTotalRecharge returns all future updates to the total recharge value
+// through a channel and also returns the current value
+func (ct *costTracker) subscribeTotalRecharge(ch chan uint64) uint64 {
+	ct.gfLock.Lock()
+	defer ct.gfLock.Unlock()
+
+	ct.totalRechargeCh = ch
+	return uint64(ct.gf * ct.utilTarget)
+}
+
+// updateStats updates the global cost factor and (if enabled) the real cost vs.
+// average estimate statistics
+func (ct *costTracker) updateStats(code, amount, servingTime, realCost uint64) {
+	avg := reqAvgTimeCost[code]
+	avgTime := avg.baseCost + amount*avg.reqCost
+	select {
+	case ct.gfUpdateCh <- gfUpdate{float64(avgTime), float64(servingTime)}:
+	default:
+	}
+	if makeCostStats {
+		realCost <<= 4
+		l := 0
+		for l < 9 && realCost > avgTime {
+			l++
+			realCost >>= 1
+		}
+		atomic.AddUint64(&ct.stats[code][l], 1)
+	}
+}
+
+// realCost calculates the final cost of a request based on actual serving time,
+// incoming and outgoing message size
+//
+// Note: message size is only taken into account if bandwidth limitation is applied
+// and the cost based on either message size is greater than the cost based on
+// serving time. A maximum of the three costs is applied instead of their sum
+// because the three limited resources (serving thread time and i/o bandwidth) can
+// also be maxed out simultaneously.
+func (ct *costTracker) realCost(servingTime uint64, inSize, outSize uint32) uint64 {
+	cost := float64(servingTime)
+	inSizeCost := float64(inSize) * ct.inSizeFactor
+	if inSizeCost > cost {
+		cost = inSizeCost
+	}
+	outSizeCost := float64(outSize) * ct.outSizeFactor
+	if outSizeCost > cost {
+		cost = outSizeCost
+	}
+	return uint64(cost * ct.globalFactor())
+}
+
+// printStats prints the distribution of real request cost relative to the average estimates
+func (ct *costTracker) printStats() {
+	if ct.stats == nil {
+		return
+	}
+	for code, arr := range ct.stats {
+		log.Info("Request cost statistics", "code", code, "1/16", arr[0], "1/8", arr[1], "1/4", arr[2], "1/2", arr[3], "1", arr[4], "2", arr[5], "4", arr[6], "8", arr[7], "16", arr[8], ">16", arr[9])
+	}
+}
+
+type (
+	// requestCostTable assigns a cost estimate function to each request type
+	// which is a linear function of the requested amount
+	// (cost = baseCost + reqCost * amount)
+	requestCostTable map[uint64]*requestCosts
+	requestCosts     struct {
+		baseCost, reqCost uint64
+	}
+
+	// RequestCostList is a list representation of request costs which is used for
+	// database storage and communication through the network
+	RequestCostList     []requestCostListItem
+	requestCostListItem struct {
+		MsgCode, BaseCost, ReqCost uint64
+	}
+)
+
+// getCost calculates the estimated cost for a given request type and amount
+func (table requestCostTable) getCost(code, amount uint64) uint64 {
+	costs := table[code]
+	return costs.baseCost + amount*costs.reqCost
+}
+
+// decode converts a cost list to a cost table
+func (list RequestCostList) decode() requestCostTable {
+	table := make(requestCostTable)
+	for _, e := range list {
+		table[e.MsgCode] = &requestCosts{
+			baseCost: e.BaseCost,
+			reqCost:  e.ReqCost,
+		}
+	}
+	return table
+}
+
+// testCostList returns a dummy request cost list used by tests
+func testCostList() RequestCostList {
+	cl := make(RequestCostList, len(reqAvgTimeCost))
+	var max uint64
+	for code := range reqAvgTimeCost {
+		if code > max {
+			max = code
+		}
+	}
+	i := 0
+	for code := uint64(0); code <= max; code++ {
+		if _, ok := reqAvgTimeCost[code]; ok {
+			cl[i].MsgCode = code
+			cl[i].BaseCost = 0
+			cl[i].ReqCost = 0
+			i++
+		}
+	}
+	return cl
+}
diff --git a/les/distributor.go b/les/distributor.go
index f90765b62..1de267f27 100644
--- a/les/distributor.go
+++ b/les/distributor.go
@@ -14,20 +14,21 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package light implements on-demand retrieval capable state and chain objects
-// for the Ethereum Light Client.
 package les
 
 import (
 	"container/list"
 	"sync"
 	"time"
+
+	"github.com/ethereum/go-ethereum/common/mclock"
 )
 
 // requestDistributor implements a mechanism that distributes requests to
 // suitable peers, obeying flow control rules and prioritizing them in creation
 // order (even when a resend is necessary).
 type requestDistributor struct {
+	clock            mclock.Clock
 	reqQueue         *list.List
 	lastReqOrder     uint64
 	peers            map[distPeer]struct{}
@@ -67,8 +68,9 @@ type distReq struct {
 }
 
 // newRequestDistributor creates a new request distributor
-func newRequestDistributor(peers *peerSet, stopChn chan struct{}) *requestDistributor {
+func newRequestDistributor(peers *peerSet, stopChn chan struct{}, clock mclock.Clock) *requestDistributor {
 	d := &requestDistributor{
+		clock:    clock,
 		reqQueue: list.New(),
 		loopChn:  make(chan struct{}, 2),
 		stopChn:  stopChn,
@@ -148,7 +150,7 @@ func (d *requestDistributor) loop() {
 						wait = distMaxWait
 					}
 					go func() {
-						time.Sleep(wait)
+						d.clock.Sleep(wait)
 						d.loopChn <- struct{}{}
 					}()
 					break loop
diff --git a/les/distributor_test.go b/les/distributor_test.go
index 8c7621f26..d2247212c 100644
--- a/les/distributor_test.go
+++ b/les/distributor_test.go
@@ -14,8 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package light implements on-demand retrieval capable state and chain objects
-// for the Ethereum Light Client.
 package les
 
 import (
@@ -23,6 +21,8 @@ import (
 	"sync"
 	"testing"
 	"time"
+
+	"github.com/ethereum/go-ethereum/common/mclock"
 )
 
 type testDistReq struct {
@@ -121,7 +121,7 @@ func testRequestDistributor(t *testing.T, resend bool) {
 	stop := make(chan struct{})
 	defer close(stop)
 
-	dist := newRequestDistributor(nil, stop)
+	dist := newRequestDistributor(nil, stop, &mclock.System{})
 	var peers [testDistPeerCount]*testDistPeer
 	for i := range peers {
 		peers[i] = &testDistPeer{}
diff --git a/les/fetcher.go b/les/fetcher.go
index aa3101af7..057552f53 100644
--- a/les/fetcher.go
+++ b/les/fetcher.go
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
@@ -559,7 +558,7 @@ func (f *lightFetcher) newFetcherDistReq(bestHash common.Hash, reqID uint64, bes
 			f.lock.Unlock()
 
 			cost := p.GetRequestCost(GetBlockHeadersMsg, int(bestAmount))
-			p.fcServer.QueueRequest(reqID, cost)
+			p.fcServer.QueuedRequest(reqID, cost)
 			f.reqMu.Lock()
 			f.requested[reqID] = fetchRequest{hash: bestHash, amount: bestAmount, peer: p, sent: mclock.Now()}
 			f.reqMu.Unlock()
diff --git a/les/flowcontrol/control.go b/les/flowcontrol/control.go
index 8ef4ba511..c03f673b2 100644
--- a/les/flowcontrol/control.go
+++ b/les/flowcontrol/control.go
@@ -18,166 +18,339 @@
 package flowcontrol
 
 import (
+	"fmt"
 	"sync"
 	"time"
 
 	"github.com/ethereum/go-ethereum/common/mclock"
+	"github.com/ethereum/go-ethereum/log"
 )
 
-const fcTimeConst = time.Millisecond
+const (
+	// fcTimeConst is the time constant applied for MinRecharge during linear
+	// buffer recharge period
+	fcTimeConst = time.Millisecond
+	// DecParamDelay is applied at server side when decreasing capacity in order to
+	// avoid a buffer underrun error due to requests sent by the client before
+	// receiving the capacity update announcement
+	DecParamDelay = time.Second * 2
+	// keepLogs is the duration of keeping logs; logging is not used if zero
+	keepLogs = 0
+)
 
+// ServerParams are the flow control parameters specified by a server for a client
+//
+// Note: a server can assign different amounts of capacity to each client by giving
+// different parameters to them.
 type ServerParams struct {
 	BufLimit, MinRecharge uint64
 }
 
+// scheduledUpdate represents a delayed flow control parameter update
+type scheduledUpdate struct {
+	time   mclock.AbsTime
+	params ServerParams
+}
+
+// ClientNode is the flow control system's representation of a client
+// (used in server mode only)
 type ClientNode struct {
-	params   *ServerParams
-	bufValue uint64
-	lastTime mclock.AbsTime
-	lock     sync.Mutex
-	cm       *ClientManager
-	cmNode   *cmNode
+	params         ServerParams
+	bufValue       uint64
+	lastTime       mclock.AbsTime
+	updateSchedule []scheduledUpdate
+	sumCost        uint64            // sum of req costs received from this client
+	accepted       map[uint64]uint64 // value = sumCost after accepting the given req
+	lock           sync.Mutex
+	cm             *ClientManager
+	log            *logger
+	cmNodeFields
 }
 
-func NewClientNode(cm *ClientManager, params *ServerParams) *ClientNode {
+// NewClientNode returns a new ClientNode
+func NewClientNode(cm *ClientManager, params ServerParams) *ClientNode {
 	node := &ClientNode{
 		cm:       cm,
 		params:   params,
 		bufValue: params.BufLimit,
-		lastTime: mclock.Now(),
+		lastTime: cm.clock.Now(),
+		accepted: make(map[uint64]uint64),
+	}
+	if keepLogs > 0 {
+		node.log = newLogger(keepLogs)
 	}
-	node.cmNode = cm.addNode(node)
+	cm.connect(node)
 	return node
 }
 
-func (peer *ClientNode) Remove(cm *ClientManager) {
-	cm.removeNode(peer.cmNode)
+// Disconnect should be called when a client is disconnected
+func (node *ClientNode) Disconnect() {
+	node.cm.disconnect(node)
+}
+
+// update recalculates the buffer value at a specified time while also performing
+// scheduled flow control parameter updates if necessary
+func (node *ClientNode) update(now mclock.AbsTime) {
+	for len(node.updateSchedule) > 0 && node.updateSchedule[0].time <= now {
+		node.recalcBV(node.updateSchedule[0].time)
+		node.updateParams(node.updateSchedule[0].params, now)
+		node.updateSchedule = node.updateSchedule[1:]
+	}
+	node.recalcBV(now)
 }
 
-func (peer *ClientNode) recalcBV(time mclock.AbsTime) {
-	dt := uint64(time - peer.lastTime)
-	if time < peer.lastTime {
+// recalcBV recalculates the buffer value at a specified time
+func (node *ClientNode) recalcBV(now mclock.AbsTime) {
+	dt := uint64(now - node.lastTime)
+	if now < node.lastTime {
 		dt = 0
 	}
-	peer.bufValue += peer.params.MinRecharge * dt / uint64(fcTimeConst)
-	if peer.bufValue > peer.params.BufLimit {
-		peer.bufValue = peer.params.BufLimit
+	node.bufValue += node.params.MinRecharge * dt / uint64(fcTimeConst)
+	if node.bufValue > node.params.BufLimit {
+		node.bufValue = node.params.BufLimit
+	}
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("updated  bv=%d  MRR=%d  BufLimit=%d", node.bufValue, node.params.MinRecharge, node.params.BufLimit))
 	}
-	peer.lastTime = time
+	node.lastTime = now
 }
 
-func (peer *ClientNode) AcceptRequest() (uint64, bool) {
-	peer.lock.Lock()
-	defer peer.lock.Unlock()
+// UpdateParams updates the flow control parameters of a client node
+func (node *ClientNode) UpdateParams(params ServerParams) {
+	node.lock.Lock()
+	defer node.lock.Unlock()
+
+	now := node.cm.clock.Now()
+	node.update(now)
+	if params.MinRecharge >= node.params.MinRecharge {
+		node.updateSchedule = nil
+		node.updateParams(params, now)
+	} else {
+		for i, s := range node.updateSchedule {
+			if params.MinRecharge >= s.params.MinRecharge {
+				s.params = params
+				node.updateSchedule = node.updateSchedule[:i+1]
+				return
+			}
+		}
+		node.updateSchedule = append(node.updateSchedule, scheduledUpdate{time: now + mclock.AbsTime(DecParamDelay), params: params})
+	}
+}
 
-	time := mclock.Now()
-	peer.recalcBV(time)
-	return peer.bufValue, peer.cm.accept(peer.cmNode, time)
+// updateParams updates the flow control parameters of the node
+func (node *ClientNode) updateParams(params ServerParams, now mclock.AbsTime) {
+	diff := params.BufLimit - node.params.BufLimit
+	if int64(diff) > 0 {
+		node.bufValue += diff
+	} else if node.bufValue > params.BufLimit {
+		node.bufValue = params.BufLimit
+	}
+	node.cm.updateParams(node, params, now)
 }
 
-func (peer *ClientNode) RequestProcessed(cost uint64) (bv, realCost uint64) {
-	peer.lock.Lock()
-	defer peer.lock.Unlock()
+// AcceptRequest returns whether a new request can be accepted and the missing
+// buffer amount if it was rejected due to a buffer underrun. If accepted, maxCost
+// is deducted from the flow control buffer.
+func (node *ClientNode) AcceptRequest(reqID, index, maxCost uint64) (accepted bool, bufShort uint64, priority int64) {
+	node.lock.Lock()
+	defer node.lock.Unlock()
 
-	time := mclock.Now()
-	peer.recalcBV(time)
-	peer.bufValue -= cost
-	rcValue, rcost := peer.cm.processed(peer.cmNode, time)
-	if rcValue < peer.params.BufLimit {
-		bv := peer.params.BufLimit - rcValue
-		if bv > peer.bufValue {
-			peer.bufValue = bv
+	now := node.cm.clock.Now()
+	node.update(now)
+	if maxCost > node.bufValue {
+		if node.log != nil {
+			node.log.add(now, fmt.Sprintf("rejected  reqID=%d  bv=%d  maxCost=%d", reqID, node.bufValue, maxCost))
+			node.log.dump(now)
 		}
+		return false, maxCost - node.bufValue, 0
+	}
+	node.bufValue -= maxCost
+	node.sumCost += maxCost
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("accepted  reqID=%d  bv=%d  maxCost=%d  sumCost=%d", reqID, node.bufValue, maxCost, node.sumCost))
+	}
+	node.accepted[index] = node.sumCost
+	return true, 0, node.cm.accepted(node, maxCost, now)
+}
+
+// RequestProcessed should be called when the request has been processed
+func (node *ClientNode) RequestProcessed(reqID, index, maxCost, realCost uint64) (bv uint64) {
+	node.lock.Lock()
+	defer node.lock.Unlock()
+
+	now := node.cm.clock.Now()
+	node.update(now)
+	node.cm.processed(node, maxCost, realCost, now)
+	bv = node.bufValue + node.sumCost - node.accepted[index]
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("processed  reqID=%d  bv=%d  maxCost=%d  realCost=%d  sumCost=%d  oldSumCost=%d  reportedBV=%d", reqID, node.bufValue, maxCost, realCost, node.sumCost, node.accepted[index], bv))
 	}
-	return peer.bufValue, rcost
+	delete(node.accepted, index)
+	return
 }
 
+// ServerNode is the flow control system's representation of a server
+// (used in client mode only)
 type ServerNode struct {
+	clock       mclock.Clock
 	bufEstimate uint64
+	bufRecharge bool
 	lastTime    mclock.AbsTime
-	params      *ServerParams
+	params      ServerParams
 	sumCost     uint64            // sum of req costs sent to this server
 	pending     map[uint64]uint64 // value = sumCost after sending the given req
+	log         *logger
 	lock        sync.RWMutex
 }
 
-func NewServerNode(params *ServerParams) *ServerNode {
-	return &ServerNode{
+// NewServerNode returns a new ServerNode
+func NewServerNode(params ServerParams, clock mclock.Clock) *ServerNode {
+	node := &ServerNode{
+		clock:       clock,
 		bufEstimate: params.BufLimit,
-		lastTime:    mclock.Now(),
+		bufRecharge: false,
+		lastTime:    clock.Now(),
 		params:      params,
 		pending:     make(map[uint64]uint64),
 	}
+	if keepLogs > 0 {
+		node.log = newLogger(keepLogs)
+	}
+	return node
 }
 
-func (peer *ServerNode) recalcBLE(time mclock.AbsTime) {
-	dt := uint64(time - peer.lastTime)
-	if time < peer.lastTime {
-		dt = 0
-	}
-	peer.bufEstimate += peer.params.MinRecharge * dt / uint64(fcTimeConst)
-	if peer.bufEstimate > peer.params.BufLimit {
-		peer.bufEstimate = peer.params.BufLimit
+// UpdateParams updates the flow control parameters of the node
+func (node *ServerNode) UpdateParams(params ServerParams) {
+	node.lock.Lock()
+	defer node.lock.Unlock()
+
+	node.recalcBLE(mclock.Now())
+	if params.BufLimit > node.params.BufLimit {
+		node.bufEstimate += params.BufLimit - node.params.BufLimit
+	} else {
+		if node.bufEstimate > params.BufLimit {
+			node.bufEstimate = params.BufLimit
+		}
 	}
-	peer.lastTime = time
+	node.params = params
 }
 
-// safetyMargin is added to the flow control waiting time when estimated buffer value is low
-const safetyMargin = time.Millisecond
-
-func (peer *ServerNode) canSend(maxCost uint64) (time.Duration, float64) {
-	peer.recalcBLE(mclock.Now())
-	maxCost += uint64(safetyMargin) * peer.params.MinRecharge / uint64(fcTimeConst)
-	if maxCost > peer.params.BufLimit {
-		maxCost = peer.params.BufLimit
+// recalcBLE recalculates the lowest estimate for the client's buffer value at
+// the given server at the specified time
+func (node *ServerNode) recalcBLE(now mclock.AbsTime) {
+	if now < node.lastTime {
+		return
+	}
+	if node.bufRecharge {
+		dt := uint64(now - node.lastTime)
+		node.bufEstimate += node.params.MinRecharge * dt / uint64(fcTimeConst)
+		if node.bufEstimate >= node.params.BufLimit {
+			node.bufEstimate = node.params.BufLimit
+			node.bufRecharge = false
+		}
 	}
-	if peer.bufEstimate >= maxCost {
-		return 0, float64(peer.bufEstimate-maxCost) / float64(peer.params.BufLimit)
+	node.lastTime = now
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("updated  bufEst=%d  MRR=%d  BufLimit=%d", node.bufEstimate, node.params.MinRecharge, node.params.BufLimit))
 	}
-	return time.Duration((maxCost - peer.bufEstimate) * uint64(fcTimeConst) / peer.params.MinRecharge), 0
 }
 
+// safetyMargin is added to the flow control waiting time when estimated buffer value is low
+const safetyMargin = time.Millisecond
+
 // CanSend returns the minimum waiting time required before sending a request
 // with the given maximum estimated cost. Second return value is the relative
 // estimated buffer level after sending the request (divided by BufLimit).
-func (peer *ServerNode) CanSend(maxCost uint64) (time.Duration, float64) {
-	peer.lock.RLock()
-	defer peer.lock.RUnlock()
+func (node *ServerNode) CanSend(maxCost uint64) (time.Duration, float64) {
+	node.lock.RLock()
+	defer node.lock.RUnlock()
 
-	return peer.canSend(maxCost)
+	now := node.clock.Now()
+	node.recalcBLE(now)
+	maxCost += uint64(safetyMargin) * node.params.MinRecharge / uint64(fcTimeConst)
+	if maxCost > node.params.BufLimit {
+		maxCost = node.params.BufLimit
+	}
+	if node.bufEstimate >= maxCost {
+		relBuf := float64(node.bufEstimate-maxCost) / float64(node.params.BufLimit)
+		if node.log != nil {
+			node.log.add(now, fmt.Sprintf("canSend  bufEst=%d  maxCost=%d  true  relBuf=%f", node.bufEstimate, maxCost, relBuf))
+		}
+		return 0, relBuf
+	}
+	timeLeft := time.Duration((maxCost - node.bufEstimate) * uint64(fcTimeConst) / node.params.MinRecharge)
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("canSend  bufEst=%d  maxCost=%d  false  timeLeft=%v", node.bufEstimate, maxCost, timeLeft))
+	}
+	return timeLeft, 0
 }
 
-// QueueRequest should be called when the request has been assigned to the given
+// QueuedRequest should be called when the request has been assigned to the given
 // server node, before putting it in the send queue. It is mandatory that requests
-// are sent in the same order as the QueueRequest calls are made.
-func (peer *ServerNode) QueueRequest(reqID, maxCost uint64) {
-	peer.lock.Lock()
-	defer peer.lock.Unlock()
+// are sent in the same order as the QueuedRequest calls are made.
+func (node *ServerNode) QueuedRequest(reqID, maxCost uint64) {
+	node.lock.Lock()
+	defer node.lock.Unlock()
 
-	peer.bufEstimate -= maxCost
-	peer.sumCost += maxCost
-	peer.pending[reqID] = peer.sumCost
+	now := node.clock.Now()
+	node.recalcBLE(now)
+	// Note: we do not know when requests actually arrive to the server so bufRecharge
+	// is not turned on here if buffer was full; in this case it is going to be turned
+	// on by the first reply's bufValue feedback
+	if node.bufEstimate >= maxCost {
+		node.bufEstimate -= maxCost
+	} else {
+		log.Error("Queued request with insufficient buffer estimate")
+		node.bufEstimate = 0
+	}
+	node.sumCost += maxCost
+	node.pending[reqID] = node.sumCost
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("queued  reqID=%d  bufEst=%d  maxCost=%d  sumCost=%d", reqID, node.bufEstimate, maxCost, node.sumCost))
+	}
 }
 
-// GotReply adjusts estimated buffer value according to the value included in
+// ReceivedReply adjusts estimated buffer value according to the value included in
 // the latest request reply.
-func (peer *ServerNode) GotReply(reqID, bv uint64) {
-
-	peer.lock.Lock()
-	defer peer.lock.Unlock()
+func (node *ServerNode) ReceivedReply(reqID, bv uint64) {
+	node.lock.Lock()
+	defer node.lock.Unlock()
 
-	if bv > peer.params.BufLimit {
-		bv = peer.params.BufLimit
+	now := node.clock.Now()
+	node.recalcBLE(now)
+	if bv > node.params.BufLimit {
+		bv = node.params.BufLimit
 	}
-	sc, ok := peer.pending[reqID]
+	sc, ok := node.pending[reqID]
 	if !ok {
 		return
 	}
-	delete(peer.pending, reqID)
-	cc := peer.sumCost - sc
-	peer.bufEstimate = 0
+	delete(node.pending, reqID)
+	cc := node.sumCost - sc
+	newEstimate := uint64(0)
 	if bv > cc {
-		peer.bufEstimate = bv - cc
+		newEstimate = bv - cc
+	}
+	if newEstimate > node.bufEstimate {
+		// Note: we never reduce the buffer estimate based on the reported value because
+		// this can only happen because of the delayed delivery of the latest reply.
+		// The lowest estimate based on the previous reply can still be considered valid.
+		node.bufEstimate = newEstimate
+	}
+
+	node.bufRecharge = node.bufEstimate < node.params.BufLimit
+	node.lastTime = now
+	if node.log != nil {
+		node.log.add(now, fmt.Sprintf("received  reqID=%d  bufEst=%d  reportedBv=%d  sumCost=%d  oldSumCost=%d", reqID, node.bufEstimate, bv, node.sumCost, sc))
+	}
+}
+
+// DumpLogs dumps the event log if logging is used
+func (node *ServerNode) DumpLogs() {
+	node.lock.Lock()
+	defer node.lock.Unlock()
+
+	if node.log != nil {
+		node.log.dump(node.clock.Now())
 	}
-	peer.lastTime = mclock.Now()
 }
diff --git a/les/flowcontrol/logger.go b/les/flowcontrol/logger.go
new file mode 100644
index 000000000..fcd1285a5
--- /dev/null
+++ b/les/flowcontrol/logger.go
@@ -0,0 +1,65 @@
+// Copyright 2018 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package flowcontrol
+
+import (
+	"fmt"
+	"time"
+
+	"github.com/ethereum/go-ethereum/common/mclock"
+)
+
+// logger collects events in string format and discards events older than the
+// "keep" parameter
+type logger struct {
+	events           map[uint64]logEvent
+	writePtr, delPtr uint64
+	keep             time.Duration
+}
+
+// logEvent describes a single event
+type logEvent struct {
+	time  mclock.AbsTime
+	event string
+}
+
+// newLogger creates a new logger
+func newLogger(keep time.Duration) *logger {
+	return &logger{
+		events: make(map[uint64]logEvent),
+		keep:   keep,
+	}
+}
+
+// add adds a new event and discards old events if possible
+func (l *logger) add(now mclock.AbsTime, event string) {
+	keepAfter := now - mclock.AbsTime(l.keep)
+	for l.delPtr < l.writePtr && l.events[l.delPtr].time <= keepAfter {
+		delete(l.events, l.delPtr)
+		l.delPtr++
+	}
+	l.events[l.writePtr] = logEvent{now, event}
+	l.writePtr++
+}
+
+// dump prints all stored events
+func (l *logger) dump(now mclock.AbsTime) {
+	for i := l.delPtr; i < l.writePtr; i++ {
+		e := l.events[i]
+		fmt.Println(time.Duration(e.time-now), e.event)
+	}
+}
diff --git a/les/flowcontrol/manager.go b/les/flowcontrol/manager.go
index 28cc6f0fe..532e6a405 100644
--- a/les/flowcontrol/manager.go
+++ b/les/flowcontrol/manager.go
@@ -1,4 +1,4 @@
-// Copyright 2016 The go-ethereum Authors
+// Copyright 2018 The go-ethereum Authors
 // This file is part of the go-ethereum library.
 //
 // The go-ethereum library is free software: you can redistribute it and/or modify
@@ -14,211 +14,388 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package flowcontrol implements a client side flow control mechanism
 package flowcontrol
 
 import (
+	"fmt"
+	"math"
 	"sync"
 	"time"
 
 	"github.com/ethereum/go-ethereum/common/mclock"
+	"github.com/ethereum/go-ethereum/common/prque"
 )
 
-const rcConst = 1000000
-
-type cmNode struct {
-	node                         *ClientNode
-	lastUpdate                   mclock.AbsTime
-	serving, recharging          bool
-	rcWeight                     uint64
-	rcValue, rcDelta, startValue int64
-	finishRecharge               mclock.AbsTime
+// cmNodeFields are ClientNode fields used by the client manager
+// Note: these fields are locked by the client manager's mutex
+type cmNodeFields struct {
+	corrBufValue   int64 // buffer value adjusted with the extra recharge amount
+	rcLastIntValue int64 // past recharge integrator value when corrBufValue was last updated
+	rcFullIntValue int64 // future recharge integrator value when corrBufValue will reach maximum
+	queueIndex     int   // position in the recharge queue (-1 if not queued)
 }
 
-func (node *cmNode) update(time mclock.AbsTime) {
-	dt := int64(time - node.lastUpdate)
-	node.rcValue += node.rcDelta * dt / rcConst
-	node.lastUpdate = time
-	if node.recharging && time >= node.finishRecharge {
-		node.recharging = false
-		node.rcDelta = 0
-		node.rcValue = 0
-	}
+// FixedPointMultiplier is applied to the recharge integrator and the recharge curve.
+//
+// Note: fixed point arithmetic is required for the integrator because it is a
+// constantly increasing value that can wrap around int64 limits (which behavior is
+// also supported by the priority queue). A floating point value would gradually lose
+// precision in this application.
+// The recharge curve and all recharge values are encoded as fixed point because
+// sumRecharge is frequently updated by adding or subtracting individual recharge
+// values and perfect precision is required.
+const FixedPointMultiplier = 1000000
+
+var (
+	capFactorDropTC         = 1 / float64(time.Second*10) // time constant for dropping the capacity factor
+	capFactorRaiseTC        = 1 / float64(time.Hour)      // time constant for raising the capacity factor
+	capFactorRaiseThreshold = 0.75                        // connected / total capacity ratio threshold for raising the capacity factor
+)
+
+// ClientManager controls the capacity assigned to the clients of a server.
+// Since ServerParams guarantee a safe lower estimate for processable requests
+// even in case of all clients being active, ClientManager calculates a
+// corrigated buffer value and usually allows a higher remaining buffer value
+// to be returned with each reply.
+type ClientManager struct {
+	clock     mclock.Clock
+	lock      sync.Mutex
+	enabledCh chan struct{}
+
+	curve                                      PieceWiseLinear
+	sumRecharge, totalRecharge, totalConnected uint64
+	capLogFactor, totalCapacity                float64
+	capLastUpdate                              mclock.AbsTime
+	totalCapacityCh                            chan uint64
+
+	// recharge integrator is increasing in each moment with a rate of
+	// (totalRecharge / sumRecharge)*FixedPointMultiplier or 0 if sumRecharge==0
+	rcLastUpdate   mclock.AbsTime // last time the recharge integrator was updated
+	rcLastIntValue int64          // last updated value of the recharge integrator
+	// recharge queue is a priority queue with currently recharging client nodes
+	// as elements. The priority value is rcFullIntValue which allows to quickly
+	// determine which client will first finish recharge.
+	rcQueue *prque.Prque
 }
 
-func (node *cmNode) set(serving bool, simReqCnt, sumWeight uint64) {
-	if node.serving && !serving {
-		node.recharging = true
-		sumWeight += node.rcWeight
+// NewClientManager returns a new client manager.
+// Client manager enhances flow control performance by allowing client buffers
+// to recharge quicker than the minimum guaranteed recharge rate if possible.
+// The sum of all minimum recharge rates (sumRecharge) is updated each time
+// a clients starts or finishes buffer recharging. Then an adjusted total
+// recharge rate is calculated using a piecewise linear recharge curve:
+//
+// totalRecharge = curve(sumRecharge)
+// (totalRecharge >= sumRecharge is enforced)
+//
+// Then the "bonus" buffer recharge is distributed between currently recharging
+// clients proportionally to their minimum recharge rates.
+//
+// Note: total recharge is proportional to the average number of parallel running
+// serving threads. A recharge value of 1000000 corresponds to one thread in average.
+// The maximum number of allowed serving threads should always be considerably
+// higher than the targeted average number.
+//
+// Note 2: although it is possible to specify a curve allowing the total target
+// recharge starting from zero sumRecharge, it makes sense to add a linear ramp
+// starting from zero in order to not let a single low-priority client use up
+// the entire server capacity and thus ensure quick availability for others at
+// any moment.
+func NewClientManager(curve PieceWiseLinear, clock mclock.Clock) *ClientManager {
+	cm := &ClientManager{
+		clock:         clock,
+		rcQueue:       prque.New(func(a interface{}, i int) { a.(*ClientNode).queueIndex = i }),
+		capLastUpdate: clock.Now(),
 	}
-	node.serving = serving
-	if node.recharging && serving {
-		node.recharging = false
-		sumWeight -= node.rcWeight
+	if curve != nil {
+		cm.SetRechargeCurve(curve)
 	}
+	return cm
+}
 
-	node.rcDelta = 0
-	if serving {
-		node.rcDelta = int64(rcConst / simReqCnt)
-	}
-	if node.recharging {
-		node.rcDelta = -int64(node.node.cm.rcRecharge * node.rcWeight / sumWeight)
-		node.finishRecharge = node.lastUpdate + mclock.AbsTime(node.rcValue*rcConst/(-node.rcDelta))
+// SetRechargeCurve updates the recharge curve
+func (cm *ClientManager) SetRechargeCurve(curve PieceWiseLinear) {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
+
+	now := cm.clock.Now()
+	cm.updateRecharge(now)
+	cm.updateCapFactor(now, false)
+	cm.curve = curve
+	if len(curve) > 0 {
+		cm.totalRecharge = curve[len(curve)-1].Y
+	} else {
+		cm.totalRecharge = 0
 	}
+	cm.refreshCapacity()
 }
 
-type ClientManager struct {
-	lock                             sync.Mutex
-	nodes                            map[*cmNode]struct{}
-	simReqCnt, sumWeight, rcSumValue uint64
-	maxSimReq, maxRcSum              uint64
-	rcRecharge                       uint64
-	resumeQueue                      chan chan bool
-	time                             mclock.AbsTime
+// connect should be called when a client is connected, before passing it to any
+// other ClientManager function
+func (cm *ClientManager) connect(node *ClientNode) {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
+
+	now := cm.clock.Now()
+	cm.updateRecharge(now)
+	node.corrBufValue = int64(node.params.BufLimit)
+	node.rcLastIntValue = cm.rcLastIntValue
+	node.queueIndex = -1
+	cm.updateCapFactor(now, true)
+	cm.totalConnected += node.params.MinRecharge
 }
 
-func NewClientManager(rcTarget, maxSimReq, maxRcSum uint64) *ClientManager {
-	cm := &ClientManager{
-		nodes:       make(map[*cmNode]struct{}),
-		resumeQueue: make(chan chan bool),
-		rcRecharge:  rcConst * rcConst / (100*rcConst/rcTarget - rcConst),
-		maxSimReq:   maxSimReq,
-		maxRcSum:    maxRcSum,
-	}
-	go cm.queueProc()
-	return cm
+// disconnect should be called when a client is disconnected
+func (cm *ClientManager) disconnect(node *ClientNode) {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
+
+	now := cm.clock.Now()
+	cm.updateRecharge(cm.clock.Now())
+	cm.updateCapFactor(now, true)
+	cm.totalConnected -= node.params.MinRecharge
 }
 
-func (self *ClientManager) Stop() {
-	self.lock.Lock()
-	defer self.lock.Unlock()
+// accepted is called when a request with given maximum cost is accepted.
+// It returns a priority indicator for the request which is used to determine placement
+// in the serving queue. Older requests have higher priority by default. If the client
+// is almost out of buffer, request priority is reduced.
+func (cm *ClientManager) accepted(node *ClientNode, maxCost uint64, now mclock.AbsTime) (priority int64) {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
 
-	// signal any waiting accept routines to return false
-	self.nodes = make(map[*cmNode]struct{})
-	close(self.resumeQueue)
+	cm.updateNodeRc(node, -int64(maxCost), &node.params, now)
+	rcTime := (node.params.BufLimit - uint64(node.corrBufValue)) * FixedPointMultiplier / node.params.MinRecharge
+	return -int64(now) - int64(rcTime)
 }
 
-func (self *ClientManager) addNode(cnode *ClientNode) *cmNode {
-	time := mclock.Now()
-	node := &cmNode{
-		node:           cnode,
-		lastUpdate:     time,
-		finishRecharge: time,
-		rcWeight:       1,
-	}
-	self.lock.Lock()
-	defer self.lock.Unlock()
+// processed updates the client buffer according to actual request cost after
+// serving has been finished.
+//
+// Note: processed should always be called for all accepted requests
+func (cm *ClientManager) processed(node *ClientNode, maxCost, realCost uint64, now mclock.AbsTime) {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
 
-	self.nodes[node] = struct{}{}
-	self.update(mclock.Now())
-	return node
+	if realCost > maxCost {
+		realCost = maxCost
+	}
+	cm.updateNodeRc(node, int64(maxCost-realCost), &node.params, now)
+	if uint64(node.corrBufValue) > node.bufValue {
+		if node.log != nil {
+			node.log.add(now, fmt.Sprintf("corrected  bv=%d  oldBv=%d", node.corrBufValue, node.bufValue))
+		}
+		node.bufValue = uint64(node.corrBufValue)
+	}
 }
 
-func (self *ClientManager) removeNode(node *cmNode) {
-	self.lock.Lock()
-	defer self.lock.Unlock()
+// updateParams updates the flow control parameters of a client node
+func (cm *ClientManager) updateParams(node *ClientNode, params ServerParams, now mclock.AbsTime) {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
 
-	time := mclock.Now()
-	self.stop(node, time)
-	delete(self.nodes, node)
-	self.update(time)
+	cm.updateRecharge(now)
+	cm.updateCapFactor(now, true)
+	cm.totalConnected += params.MinRecharge - node.params.MinRecharge
+	cm.updateNodeRc(node, 0, &params, now)
 }
 
-// recalc sumWeight
-func (self *ClientManager) updateNodes(time mclock.AbsTime) (rce bool) {
-	var sumWeight, rcSum uint64
-	for node := range self.nodes {
-		rc := node.recharging
-		node.update(time)
-		if rc && !node.recharging {
-			rce = true
+// updateRecharge updates the recharge integrator and checks the recharge queue
+// for nodes with recently filled buffers
+func (cm *ClientManager) updateRecharge(now mclock.AbsTime) {
+	lastUpdate := cm.rcLastUpdate
+	cm.rcLastUpdate = now
+	// updating is done in multiple steps if node buffers are filled and sumRecharge
+	// is decreased before the given target time
+	for cm.sumRecharge > 0 {
+		bonusRatio := cm.curve.ValueAt(cm.sumRecharge) / float64(cm.sumRecharge)
+		if bonusRatio < 1 {
+			bonusRatio = 1
+		}
+		dt := now - lastUpdate
+		// fetch the client that finishes first
+		rcqNode := cm.rcQueue.PopItem().(*ClientNode) // if sumRecharge > 0 then the queue cannot be empty
+		// check whether it has already finished
+		dtNext := mclock.AbsTime(float64(rcqNode.rcFullIntValue-cm.rcLastIntValue) / bonusRatio)
+		if dt < dtNext {
+			// not finished yet, put it back, update integrator according
+			// to current bonusRatio and return
+			cm.rcQueue.Push(rcqNode, -rcqNode.rcFullIntValue)
+			cm.rcLastIntValue += int64(bonusRatio * float64(dt))
+			return
 		}
-		if node.recharging {
-			sumWeight += node.rcWeight
+		lastUpdate += dtNext
+		// finished recharging, update corrBufValue and sumRecharge if necessary and do next step
+		if rcqNode.corrBufValue < int64(rcqNode.params.BufLimit) {
+			rcqNode.corrBufValue = int64(rcqNode.params.BufLimit)
+			cm.updateCapFactor(lastUpdate, true)
+			cm.sumRecharge -= rcqNode.params.MinRecharge
 		}
-		rcSum += uint64(node.rcValue)
+		cm.rcLastIntValue = rcqNode.rcFullIntValue
 	}
-	self.sumWeight = sumWeight
-	self.rcSumValue = rcSum
-	return
 }
 
-func (self *ClientManager) update(time mclock.AbsTime) {
-	for {
-		firstTime := time
-		for node := range self.nodes {
-			if node.recharging && node.finishRecharge < firstTime {
-				firstTime = node.finishRecharge
-			}
+// updateNodeRc updates a node's corrBufValue and adds an external correction value.
+// It also adds or removes the rcQueue entry and updates ServerParams and sumRecharge if necessary.
+func (cm *ClientManager) updateNodeRc(node *ClientNode, bvc int64, params *ServerParams, now mclock.AbsTime) {
+	cm.updateRecharge(now)
+	wasFull := true
+	if node.corrBufValue != int64(node.params.BufLimit) {
+		wasFull = false
+		node.corrBufValue += (cm.rcLastIntValue - node.rcLastIntValue) * int64(node.params.MinRecharge) / FixedPointMultiplier
+		if node.corrBufValue > int64(node.params.BufLimit) {
+			node.corrBufValue = int64(node.params.BufLimit)
 		}
-		if self.updateNodes(firstTime) {
-			for node := range self.nodes {
-				if node.recharging {
-					node.set(node.serving, self.simReqCnt, self.sumWeight)
-				}
-			}
-		} else {
-			self.time = time
-			return
+		node.rcLastIntValue = cm.rcLastIntValue
+	}
+	node.corrBufValue += bvc
+	if node.corrBufValue < 0 {
+		node.corrBufValue = 0
+	}
+	diff := int64(params.BufLimit - node.params.BufLimit)
+	if diff > 0 {
+		node.corrBufValue += diff
+	}
+	isFull := false
+	if node.corrBufValue >= int64(params.BufLimit) {
+		node.corrBufValue = int64(params.BufLimit)
+		isFull = true
+	}
+	sumRecharge := cm.sumRecharge
+	if !wasFull {
+		sumRecharge -= node.params.MinRecharge
+	}
+	if params != &node.params {
+		node.params = *params
+	}
+	if !isFull {
+		sumRecharge += node.params.MinRecharge
+		if node.queueIndex != -1 {
+			cm.rcQueue.Remove(node.queueIndex)
 		}
+		node.rcLastIntValue = cm.rcLastIntValue
+		node.rcFullIntValue = cm.rcLastIntValue + (int64(node.params.BufLimit)-node.corrBufValue)*FixedPointMultiplier/int64(node.params.MinRecharge)
+		cm.rcQueue.Push(node, -node.rcFullIntValue)
+	}
+	if sumRecharge != cm.sumRecharge {
+		cm.updateCapFactor(now, true)
+		cm.sumRecharge = sumRecharge
 	}
-}
 
-func (self *ClientManager) canStartReq() bool {
-	return self.simReqCnt < self.maxSimReq && self.rcSumValue < self.maxRcSum
 }
 
-func (self *ClientManager) queueProc() {
-	for rc := range self.resumeQueue {
-		for {
-			time.Sleep(time.Millisecond * 10)
-			self.lock.Lock()
-			self.update(mclock.Now())
-			cs := self.canStartReq()
-			self.lock.Unlock()
-			if cs {
-				break
+// updateCapFactor updates the total capacity factor. The capacity factor allows
+// the total capacity of the system to go over the allowed total recharge value
+// if the sum of momentarily recharging clients only exceeds the total recharge
+// allowance in a very small fraction of time.
+// The capacity factor is dropped quickly (with a small time constant) if sumRecharge
+// exceeds totalRecharge. It is raised slowly (with a large time constant) if most
+// of the total capacity is used by connected clients (totalConnected is larger than
+// totalCapacity*capFactorRaiseThreshold) and sumRecharge stays under
+// totalRecharge*totalConnected/totalCapacity.
+func (cm *ClientManager) updateCapFactor(now mclock.AbsTime, refresh bool) {
+	if cm.totalRecharge == 0 {
+		return
+	}
+	dt := now - cm.capLastUpdate
+	cm.capLastUpdate = now
+
+	var d float64
+	if cm.sumRecharge > cm.totalRecharge {
+		d = (1 - float64(cm.sumRecharge)/float64(cm.totalRecharge)) * capFactorDropTC
+	} else {
+		totalConnected := float64(cm.totalConnected)
+		var connRatio float64
+		if totalConnected < cm.totalCapacity {
+			connRatio = totalConnected / cm.totalCapacity
+		} else {
+			connRatio = 1
+		}
+		if connRatio > capFactorRaiseThreshold {
+			sumRecharge := float64(cm.sumRecharge)
+			limit := float64(cm.totalRecharge) * connRatio
+			if sumRecharge < limit {
+				d = (1 - sumRecharge/limit) * (connRatio - capFactorRaiseThreshold) * (1 / (1 - capFactorRaiseThreshold)) * capFactorRaiseTC
 			}
 		}
-		close(rc)
+	}
+	if d != 0 {
+		cm.capLogFactor += d * float64(dt)
+		if cm.capLogFactor < 0 {
+			cm.capLogFactor = 0
+		}
+		if refresh {
+			cm.refreshCapacity()
+		}
 	}
 }
 
-func (self *ClientManager) accept(node *cmNode, time mclock.AbsTime) bool {
-	self.lock.Lock()
-	defer self.lock.Unlock()
-
-	self.update(time)
-	if !self.canStartReq() {
-		resume := make(chan bool)
-		self.lock.Unlock()
-		self.resumeQueue <- resume
-		<-resume
-		self.lock.Lock()
-		if _, ok := self.nodes[node]; !ok {
-			return false // reject if node has been removed or manager has been stopped
+// refreshCapacity recalculates the total capacity value and sends an update to the subscription
+// channel if the relative change of the value since the last update is more than 0.1 percent
+func (cm *ClientManager) refreshCapacity() {
+	totalCapacity := float64(cm.totalRecharge) * math.Exp(cm.capLogFactor)
+	if totalCapacity >= cm.totalCapacity*0.999 && totalCapacity <= cm.totalCapacity*1.001 {
+		return
+	}
+	cm.totalCapacity = totalCapacity
+	if cm.totalCapacityCh != nil {
+		select {
+		case cm.totalCapacityCh <- uint64(cm.totalCapacity):
+		default:
 		}
 	}
-	self.simReqCnt++
-	node.set(true, self.simReqCnt, self.sumWeight)
-	node.startValue = node.rcValue
-	self.update(self.time)
-	return true
 }
 
-func (self *ClientManager) stop(node *cmNode, time mclock.AbsTime) {
-	if node.serving {
-		self.update(time)
-		self.simReqCnt--
-		node.set(false, self.simReqCnt, self.sumWeight)
-		self.update(time)
-	}
+// SubscribeTotalCapacity returns all future updates to the total capacity value
+// through a channel and also returns the current value
+func (cm *ClientManager) SubscribeTotalCapacity(ch chan uint64) uint64 {
+	cm.lock.Lock()
+	defer cm.lock.Unlock()
+
+	cm.totalCapacityCh = ch
+	return uint64(cm.totalCapacity)
 }
 
-func (self *ClientManager) processed(node *cmNode, time mclock.AbsTime) (rcValue, rcCost uint64) {
-	self.lock.Lock()
-	defer self.lock.Unlock()
+// PieceWiseLinear is used to describe recharge curves
+type PieceWiseLinear []struct{ X, Y uint64 }
+
+// ValueAt returns the curve's value at a given point
+func (pwl PieceWiseLinear) ValueAt(x uint64) float64 {
+	l := 0
+	h := len(pwl)
+	if h == 0 {
+		return 0
+	}
+	for h != l {
+		m := (l + h) / 2
+		if x > pwl[m].X {
+			l = m + 1
+		} else {
+			h = m
+		}
+	}
+	if l == 0 {
+		return float64(pwl[0].Y)
+	}
+	l--
+	if h == len(pwl) {
+		return float64(pwl[l].Y)
+	}
+	dx := pwl[h].X - pwl[l].X
+	if dx < 1 {
+		return float64(pwl[l].Y)
+	}
+	return float64(pwl[l].Y) + float64(pwl[h].Y-pwl[l].Y)*float64(x-pwl[l].X)/float64(dx)
+}
 
-	self.stop(node, time)
-	return uint64(node.rcValue), uint64(node.rcValue - node.startValue)
+// Valid returns true if the X coordinates of the curve points are non-strictly monotonic
+func (pwl PieceWiseLinear) Valid() bool {
+	var lastX uint64
+	for _, i := range pwl {
+		if i.X < lastX {
+			return false
+		}
+		lastX = i.X
+	}
+	return true
 }
diff --git a/les/flowcontrol/manager_test.go b/les/flowcontrol/manager_test.go
new file mode 100644
index 000000000..4e7746d40
--- /dev/null
+++ b/les/flowcontrol/manager_test.go
@@ -0,0 +1,123 @@
+// Copyright 2018 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package flowcontrol
+
+import (
+	"math/rand"
+	"testing"
+	"time"
+
+	"github.com/ethereum/go-ethereum/common/mclock"
+)
+
+type testNode struct {
+	node               *ClientNode
+	bufLimit, capacity uint64
+	waitUntil          mclock.AbsTime
+	index, totalCost   uint64
+}
+
+const (
+	testMaxCost = 1000000
+	testLength  = 100000
+)
+
+// testConstantTotalCapacity simulates multiple request sender nodes and verifies
+// whether the total amount of served requests matches the expected value based on
+// the total capacity and the duration of the test.
+// Some nodes are sending requests occasionally so that their buffer should regularly
+// reach the maximum while other nodes (the "max capacity nodes") are sending at the
+// maximum permitted rate. The max capacity nodes are changed multiple times during
+// a single test.
+func TestConstantTotalCapacity(t *testing.T) {
+	testConstantTotalCapacity(t, 10, 1, 0)
+	testConstantTotalCapacity(t, 10, 1, 1)
+	testConstantTotalCapacity(t, 30, 1, 0)
+	testConstantTotalCapacity(t, 30, 2, 3)
+	testConstantTotalCapacity(t, 100, 1, 0)
+	testConstantTotalCapacity(t, 100, 3, 5)
+	testConstantTotalCapacity(t, 100, 5, 10)
+}
+
+func testConstantTotalCapacity(t *testing.T, nodeCount, maxCapacityNodes, randomSend int) {
+	clock := &mclock.Simulated{}
+	nodes := make([]*testNode, nodeCount)
+	var totalCapacity uint64
+	for i := range nodes {
+		nodes[i] = &testNode{capacity: uint64(50000 + rand.Intn(100000))}
+		totalCapacity += nodes[i].capacity
+	}
+	m := NewClientManager(PieceWiseLinear{{0, totalCapacity}}, clock)
+	for _, n := range nodes {
+		n.bufLimit = n.capacity * 6000 //uint64(2000+rand.Intn(10000))
+		n.node = NewClientNode(m, ServerParams{BufLimit: n.bufLimit, MinRecharge: n.capacity})
+	}
+	maxNodes := make([]int, maxCapacityNodes)
+	for i := range maxNodes {
+		// we don't care if some indexes are selected multiple times
+		// in that case we have fewer max nodes
+		maxNodes[i] = rand.Intn(nodeCount)
+	}
+
+	for i := 0; i < testLength; i++ {
+		now := clock.Now()
+		for _, idx := range maxNodes {
+			for nodes[idx].send(t, now) {
+			}
+		}
+		if rand.Intn(testLength) < maxCapacityNodes*3 {
+			maxNodes[rand.Intn(maxCapacityNodes)] = rand.Intn(nodeCount)
+		}
+
+		sendCount := randomSend
+		for sendCount > 0 {
+			if nodes[rand.Intn(nodeCount)].send(t, now) {
+				sendCount--
+			}
+		}
+
+		clock.Run(time.Millisecond)
+	}
+
+	var totalCost uint64
+	for _, n := range nodes {
+		totalCost += n.totalCost
+	}
+	ratio := float64(totalCost) / float64(totalCapacity) / testLength
+	if ratio < 0.98 || ratio > 1.02 {
+		t.Errorf("totalCost/totalCapacity/testLength ratio incorrect (expected: 1, got: %f)", ratio)
+	}
+
+}
+
+func (n *testNode) send(t *testing.T, now mclock.AbsTime) bool {
+	if now < n.waitUntil {
+		return false
+	}
+	n.index++
+	if ok, _, _ := n.node.AcceptRequest(0, n.index, testMaxCost); !ok {
+		t.Fatalf("Rejected request after expected waiting time has passed")
+	}
+	rcost := uint64(rand.Int63n(testMaxCost))
+	bv := n.node.RequestProcessed(0, n.index, testMaxCost, rcost)
+	if bv < testMaxCost {
+		n.waitUntil = now + mclock.AbsTime((testMaxCost-bv)*1001000/n.capacity)
+	}
+	//n.waitUntil = now + mclock.AbsTime(float64(testMaxCost)*1001000/float64(n.capacity)*(1-float64(bv)/float64(n.bufLimit)))
+	n.totalCost += rcost
+	return true
+}
diff --git a/les/freeclient.go b/les/freeclient.go
index 5ee607be8..d859337c2 100644
--- a/les/freeclient.go
+++ b/les/freeclient.go
@@ -14,12 +14,12 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
 	"io"
 	"math"
+	"net"
 	"sync"
 	"time"
 
@@ -44,12 +44,14 @@ import (
 // value for the client. Currently the LES protocol manager uses IP addresses
 // (without port address) to identify clients.
 type freeClientPool struct {
-	db     ethdb.Database
-	lock   sync.Mutex
-	clock  mclock.Clock
-	closed bool
+	db         ethdb.Database
+	lock       sync.Mutex
+	clock      mclock.Clock
+	closed     bool
+	removePeer func(string)
 
 	connectedLimit, totalLimit int
+	freeClientCap              uint64
 
 	addressMap            map[string]*freeClientPoolEntry
 	connPool, disconnPool *prque.Prque
@@ -64,15 +66,16 @@ const (
 )
 
 // newFreeClientPool creates a new free client pool
-func newFreeClientPool(db ethdb.Database, connectedLimit, totalLimit int, clock mclock.Clock) *freeClientPool {
+func newFreeClientPool(db ethdb.Database, freeClientCap uint64, totalLimit int, clock mclock.Clock, removePeer func(string)) *freeClientPool {
 	pool := &freeClientPool{
-		db:             db,
-		clock:          clock,
-		addressMap:     make(map[string]*freeClientPoolEntry),
-		connPool:       prque.New(poolSetIndex),
-		disconnPool:    prque.New(poolSetIndex),
-		connectedLimit: connectedLimit,
-		totalLimit:     totalLimit,
+		db:            db,
+		clock:         clock,
+		addressMap:    make(map[string]*freeClientPoolEntry),
+		connPool:      prque.New(poolSetIndex),
+		disconnPool:   prque.New(poolSetIndex),
+		freeClientCap: freeClientCap,
+		totalLimit:    totalLimit,
+		removePeer:    removePeer,
 	}
 	pool.loadFromDb()
 	return pool
@@ -85,22 +88,34 @@ func (f *freeClientPool) stop() {
 	f.lock.Unlock()
 }
 
+// registerPeer implements clientPool
+func (f *freeClientPool) registerPeer(p *peer) {
+	if addr, ok := p.RemoteAddr().(*net.TCPAddr); ok {
+		if !f.connect(addr.IP.String(), p.id) {
+			f.removePeer(p.id)
+		}
+	}
+}
+
 // connect should be called after a successful handshake. If the connection was
 // rejected, there is no need to call disconnect.
-//
-// Note: the disconnectFn callback should not block.
-func (f *freeClientPool) connect(address string, disconnectFn func()) bool {
+func (f *freeClientPool) connect(address, id string) bool {
 	f.lock.Lock()
 	defer f.lock.Unlock()
 
 	if f.closed {
 		return false
 	}
+
+	if f.connectedLimit == 0 {
+		log.Debug("Client rejected", "address", address)
+		return false
+	}
 	e := f.addressMap[address]
 	now := f.clock.Now()
 	var recentUsage int64
 	if e == nil {
-		e = &freeClientPoolEntry{address: address, index: -1}
+		e = &freeClientPoolEntry{address: address, index: -1, id: id}
 		f.addressMap[address] = e
 	} else {
 		if e.connected {
@@ -115,12 +130,7 @@ func (f *freeClientPool) connect(address string, disconnectFn func()) bool {
 		i := f.connPool.PopItem().(*freeClientPoolEntry)
 		if e.linUsage+int64(connectedBias)-i.linUsage < 0 {
 			// kick it out and accept the new client
-			f.connPool.Remove(i.index)
-			f.calcLogUsage(i, now)
-			i.connected = false
-			f.disconnPool.Push(i, -i.logUsage)
-			log.Debug("Client kicked out", "address", i.address)
-			i.disconnectFn()
+			f.dropClient(i, now)
 		} else {
 			// keep the old client and reject the new one
 			f.connPool.Push(i, i.linUsage)
@@ -130,7 +140,7 @@ func (f *freeClientPool) connect(address string, disconnectFn func()) bool {
 	}
 	f.disconnPool.Remove(e.index)
 	e.connected = true
-	e.disconnectFn = disconnectFn
+	e.id = id
 	f.connPool.Push(e, e.linUsage)
 	if f.connPool.Size()+f.disconnPool.Size() > f.totalLimit {
 		f.disconnPool.Pop()
@@ -139,6 +149,13 @@ func (f *freeClientPool) connect(address string, disconnectFn func()) bool {
 	return true
 }
 
+// unregisterPeer implements clientPool
+func (f *freeClientPool) unregisterPeer(p *peer) {
+	if addr, ok := p.RemoteAddr().(*net.TCPAddr); ok {
+		f.disconnect(addr.IP.String())
+	}
+}
+
 // disconnect should be called when a connection is terminated. If the disconnection
 // was initiated by the pool itself using disconnectFn then calling disconnect is
 // not necessary but permitted.
@@ -163,6 +180,34 @@ func (f *freeClientPool) disconnect(address string) {
 	log.Debug("Client disconnected", "address", address)
 }
 
+// setConnLimit sets the maximum number of free client slots and also drops
+// some peers if necessary
+func (f *freeClientPool) setLimits(count int, totalCap uint64) {
+	f.lock.Lock()
+	defer f.lock.Unlock()
+
+	f.connectedLimit = int(totalCap / f.freeClientCap)
+	if count < f.connectedLimit {
+		f.connectedLimit = count
+	}
+	now := mclock.Now()
+	for f.connPool.Size() > f.connectedLimit {
+		i := f.connPool.PopItem().(*freeClientPoolEntry)
+		f.dropClient(i, now)
+	}
+}
+
+// dropClient disconnects a client and also moves it from the connected to the
+// disconnected pool
+func (f *freeClientPool) dropClient(i *freeClientPoolEntry, now mclock.AbsTime) {
+	f.connPool.Remove(i.index)
+	f.calcLogUsage(i, now)
+	i.connected = false
+	f.disconnPool.Push(i, -i.logUsage)
+	log.Debug("Client kicked out", "address", i.address)
+	f.removePeer(i.id)
+}
+
 // logOffset calculates the time-dependent offset for the logarithmic
 // representation of recent usage
 func (f *freeClientPool) logOffset(now mclock.AbsTime) int64 {
@@ -245,7 +290,7 @@ func (f *freeClientPool) saveToDb() {
 // even though they are close to each other at any time they may wrap around int64
 // limits over time. Comparison should be performed accordingly.
 type freeClientPoolEntry struct {
-	address            string
+	address, id        string
 	connected          bool
 	disconnectFn       func()
 	linUsage, logUsage int64
diff --git a/les/freeclient_test.go b/les/freeclient_test.go
index e95abc7aa..dc8b51a8d 100644
--- a/les/freeclient_test.go
+++ b/les/freeclient_test.go
@@ -14,13 +14,12 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package light implements on-demand retrieval capable state and chain objects
-// for the Ethereum Light Client.
 package les
 
 import (
 	"fmt"
 	"math/rand"
+	"strconv"
 	"testing"
 	"time"
 
@@ -44,32 +43,38 @@ const testFreeClientPoolTicks = 500000
 
 func testFreeClientPool(t *testing.T, connLimit, clientCount int) {
 	var (
-		clock     mclock.Simulated
-		db        = ethdb.NewMemDatabase()
-		pool      = newFreeClientPool(db, connLimit, 10000, &clock)
-		connected = make([]bool, clientCount)
-		connTicks = make([]int, clientCount)
-		disconnCh = make(chan int, clientCount)
-	)
-	peerId := func(i int) string {
-		return fmt.Sprintf("test peer #%d", i)
-	}
-	disconnFn := func(i int) func() {
-		return func() {
+		clock       mclock.Simulated
+		db          = ethdb.NewMemDatabase()
+		connected   = make([]bool, clientCount)
+		connTicks   = make([]int, clientCount)
+		disconnCh   = make(chan int, clientCount)
+		peerAddress = func(i int) string {
+			return fmt.Sprintf("addr #%d", i)
+		}
+		peerId = func(i int) string {
+			return fmt.Sprintf("id #%d", i)
+		}
+		disconnFn = func(id string) {
+			i, err := strconv.Atoi(id[4:])
+			if err != nil {
+				panic(err)
+			}
 			disconnCh <- i
 		}
-	}
+		pool = newFreeClientPool(db, 1, 10000, &clock, disconnFn)
+	)
+	pool.setLimits(connLimit, uint64(connLimit))
 
 	// pool should accept new peers up to its connected limit
 	for i := 0; i < connLimit; i++ {
-		if pool.connect(peerId(i), disconnFn(i)) {
+		if pool.connect(peerAddress(i), peerId(i)) {
 			connected[i] = true
 		} else {
 			t.Fatalf("Test peer #%d rejected", i)
 		}
 	}
 	// since all accepted peers are new and should not be kicked out, the next one should be rejected
-	if pool.connect(peerId(connLimit), disconnFn(connLimit)) {
+	if pool.connect(peerAddress(connLimit), peerId(connLimit)) {
 		connected[connLimit] = true
 		t.Fatalf("Peer accepted over connected limit")
 	}
@@ -80,11 +85,11 @@ func testFreeClientPool(t *testing.T, connLimit, clientCount int) {
 
 		i := rand.Intn(clientCount)
 		if connected[i] {
-			pool.disconnect(peerId(i))
+			pool.disconnect(peerAddress(i))
 			connected[i] = false
 			connTicks[i] += tickCounter
 		} else {
-			if pool.connect(peerId(i), disconnFn(i)) {
+			if pool.connect(peerAddress(i), peerId(i)) {
 				connected[i] = true
 				connTicks[i] -= tickCounter
 			}
@@ -93,7 +98,7 @@ func testFreeClientPool(t *testing.T, connLimit, clientCount int) {
 		for {
 			select {
 			case i := <-disconnCh:
-				pool.disconnect(peerId(i))
+				pool.disconnect(peerAddress(i))
 				if connected[i] {
 					connTicks[i] += tickCounter
 					connected[i] = false
@@ -119,20 +124,21 @@ func testFreeClientPool(t *testing.T, connLimit, clientCount int) {
 	}
 
 	// a previously unknown peer should be accepted now
-	if !pool.connect("newPeer", func() {}) {
+	if !pool.connect("newAddr", "newId") {
 		t.Fatalf("Previously unknown peer rejected")
 	}
 
 	// close and restart pool
 	pool.stop()
-	pool = newFreeClientPool(db, connLimit, 10000, &clock)
+	pool = newFreeClientPool(db, 1, 10000, &clock, disconnFn)
+	pool.setLimits(connLimit, uint64(connLimit))
 
 	// try connecting all known peers (connLimit should be filled up)
 	for i := 0; i < clientCount; i++ {
-		pool.connect(peerId(i), func() {})
+		pool.connect(peerAddress(i), peerId(i))
 	}
 	// expect pool to remember known nodes and kick out one of them to accept a new one
-	if !pool.connect("newPeer2", func() {}) {
+	if !pool.connect("newAddr2", "newId2") {
 		t.Errorf("Previously unknown peer rejected after restarting pool")
 	}
 	pool.stop()
diff --git a/les/handler.go b/les/handler.go
index 680e115b0..0352f5b03 100644
--- a/les/handler.go
+++ b/les/handler.go
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
@@ -22,12 +21,10 @@ import (
 	"encoding/json"
 	"fmt"
 	"math/big"
-	"net"
 	"sync"
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
-	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/rawdb"
@@ -90,21 +87,21 @@ type txPool interface {
 }
 
 type ProtocolManager struct {
-	lightSync   bool
-	txpool      txPool
-	txrelay     *LesTxRelay
-	networkId   uint64
-	chainConfig *params.ChainConfig
-	iConfig     *light.IndexerConfig
-	blockchain  BlockChain
-	chainDb     ethdb.Database
-	odr         *LesOdr
-	server      *LesServer
-	serverPool  *serverPool
-	clientPool  *freeClientPool
-	lesTopic    discv5.Topic
-	reqDist     *requestDistributor
-	retriever   *retrieveManager
+	lightSync    bool
+	txpool       txPool
+	txrelay      *LesTxRelay
+	networkId    uint64
+	chainConfig  *params.ChainConfig
+	iConfig      *light.IndexerConfig
+	blockchain   BlockChain
+	chainDb      ethdb.Database
+	odr          *LesOdr
+	server       *LesServer
+	serverPool   *serverPool
+	lesTopic     discv5.Topic
+	reqDist      *requestDistributor
+	retriever    *retrieveManager
+	servingQueue *servingQueue
 
 	downloader *downloader.Downloader
 	fetcher    *lightFetcher
@@ -165,6 +162,8 @@ func NewProtocolManager(
 	if odr != nil {
 		manager.retriever = odr.retriever
 		manager.reqDist = odr.retriever.dist
+	} else {
+		manager.servingQueue = newServingQueue(int64(time.Millisecond * 10))
 	}
 
 	if ulcConfig != nil {
@@ -181,7 +180,6 @@ func NewProtocolManager(
 		manager.peers.notify((*downloaderPeerNotify)(manager))
 		manager.fetcher = newLightFetcher(manager)
 	}
-
 	return manager, nil
 }
 
@@ -192,11 +190,9 @@ func (pm *ProtocolManager) removePeer(id string) {
 
 func (pm *ProtocolManager) Start(maxPeers int) {
 	pm.maxPeers = maxPeers
-
 	if pm.lightSync {
 		go pm.syncer()
 	} else {
-		pm.clientPool = newFreeClientPool(pm.chainDb, maxPeers, 10000, mclock.System{})
 		go func() {
 			for range pm.newPeerCh {
 			}
@@ -214,8 +210,9 @@ func (pm *ProtocolManager) Stop() {
 	pm.noMorePeers <- struct{}{}
 
 	close(pm.quitSync) // quits syncer, fetcher
-	if pm.clientPool != nil {
-		pm.clientPool.stop()
+
+	if pm.servingQueue != nil {
+		pm.servingQueue.stop()
 	}
 
 	// Disconnect existing sessions.
@@ -286,17 +283,8 @@ func (pm *ProtocolManager) handle(p *peer) error {
 		p.Log().Debug("Light Ethereum handshake failed", "err", err)
 		return err
 	}
-
-	if !pm.lightSync && !p.Peer.Info().Network.Trusted {
-		addr, ok := p.RemoteAddr().(*net.TCPAddr)
-		// test peer address is not a tcp address, don't use client pool if can not typecast
-		if ok {
-			id := addr.IP.String()
-			if !pm.clientPool.connect(id, func() { go pm.removePeer(p.id) }) {
-				return p2p.DiscTooManyPeers
-			}
-			defer pm.clientPool.disconnect(id)
-		}
+	if p.fcClient != nil {
+		defer p.fcClient.Disconnect()
 	}
 
 	if rw, ok := p.rw.(*meteredMsgReadWriter); ok {
@@ -309,9 +297,6 @@ func (pm *ProtocolManager) handle(p *peer) error {
 		return err
 	}
 	defer func() {
-		if pm.server != nil && pm.server.fcManager != nil && p.fcClient != nil {
-			p.fcClient.Remove(pm.server.fcManager)
-		}
 		pm.removePeer(p.id)
 	}()
 
@@ -329,31 +314,18 @@ func (pm *ProtocolManager) handle(p *peer) error {
 		}
 	}
 
-	stop := make(chan struct{})
-	defer close(stop)
-	go func() {
-		// new block announce loop
-		for {
-			select {
-			case announce := <-p.announceChn:
-				p.SendAnnounce(announce)
-			case <-stop:
-				return
-			}
-		}
-	}()
-
 	// main loop. handle incoming messages.
 	for {
 		if err := pm.handleMsg(p); err != nil {
 			p.Log().Debug("Light Ethereum message handling failed", "err", err)
+			if p.fcServer != nil {
+				p.fcServer.DumpLogs()
+			}
 			return err
 		}
 	}
 }
 
-var reqList = []uint64{GetBlockHeadersMsg, GetBlockBodiesMsg, GetCodeMsg, GetReceiptsMsg, GetProofsV1Msg, SendTxMsg, SendTxV2Msg, GetTxStatusMsg, GetHeaderProofsMsg, GetProofsV2Msg, GetHelperTrieProofsMsg}
-
 // handleMsg is invoked whenever an inbound message is received from a remote
 // peer. The remote connection is torn down upon returning any error.
 func (pm *ProtocolManager) handleMsg(p *peer) error {
@@ -364,22 +336,31 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 	}
 	p.Log().Trace("Light Ethereum message arrived", "code", msg.Code, "bytes", msg.Size)
 
-	costs := p.fcCosts[msg.Code]
-	reject := func(reqCnt, maxCnt uint64) bool {
-		if p.fcClient == nil || reqCnt > maxCnt {
-			return true
+	p.responseCount++
+	responseCount := p.responseCount
+	var (
+		maxCost uint64
+		task    *servingTask
+	)
+
+	accept := func(reqID, reqCnt, maxCnt uint64) bool {
+		if reqCnt == 0 {
+			return false
 		}
-		bufValue, _ := p.fcClient.AcceptRequest()
-		cost := costs.baseCost + reqCnt*costs.reqCost
-		if cost > pm.server.defParams.BufLimit {
-			cost = pm.server.defParams.BufLimit
+		if p.fcClient == nil || reqCnt > maxCnt {
+			return false
 		}
-		if cost > bufValue {
-			recharge := time.Duration((cost - bufValue) * 1000000 / pm.server.defParams.MinRecharge)
-			p.Log().Error("Request came too early", "recharge", common.PrettyDuration(recharge))
-			return true
+		maxCost = p.fcCosts.getCost(msg.Code, reqCnt)
+
+		if accepted, bufShort, servingPriority := p.fcClient.AcceptRequest(reqID, responseCount, maxCost); !accepted {
+			if bufShort > 0 {
+				p.Log().Error("Request came too early", "remaining", common.PrettyDuration(time.Duration(bufShort*1000000/p.fcParams.MinRecharge)))
+			}
+			return false
+		} else {
+			task = pm.servingQueue.newTask(servingPriority)
 		}
-		return false
+		return task.start()
 	}
 
 	if msg.Size > ProtocolMaxMsgSize {
@@ -389,6 +370,31 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 
 	var deliverMsg *Msg
 
+	sendResponse := func(reqID, amount uint64, reply *reply, servingTime uint64) {
+		p.responseLock.Lock()
+		defer p.responseLock.Unlock()
+
+		var replySize uint32
+		if reply != nil {
+			replySize = reply.size()
+		}
+		var realCost uint64
+		if pm.server.costTracker != nil {
+			realCost = pm.server.costTracker.realCost(servingTime, msg.Size, replySize)
+			pm.server.costTracker.updateStats(msg.Code, amount, servingTime, realCost)
+		} else {
+			realCost = maxCost
+		}
+		bv := p.fcClient.RequestProcessed(reqID, responseCount, maxCost, realCost)
+		if reply != nil {
+			p.queueSend(func() {
+				if err := reply.send(bv); err != nil {
+					p.errCh <- err
+				}
+			})
+		}
+	}
+
 	// Handle the message depending on its contents
 	switch msg.Code {
 	case StatusMsg:
@@ -399,25 +405,33 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 	// Block header query, collect the requested headers and reply
 	case AnnounceMsg:
 		p.Log().Trace("Received announce message")
-		if p.announceType == announceTypeNone {
-			return errResp(ErrUnexpectedResponse, "")
-		}
 		var req announceData
 		if err := msg.Decode(&req); err != nil {
 			return errResp(ErrDecode, "%v: %v", msg, err)
 		}
 
-		if p.announceType == announceTypeSigned {
-			if err := req.checkSignature(p.ID()); err != nil {
-				p.Log().Trace("Invalid announcement signature", "err", err)
-				return err
-			}
-			p.Log().Trace("Valid announcement signature")
+		update, size := req.Update.decode()
+		if p.rejectUpdate(size) {
+			return errResp(ErrRequestRejected, "")
 		}
+		p.updateFlowControl(update)
 
-		p.Log().Trace("Announce message content", "number", req.Number, "hash", req.Hash, "td", req.Td, "reorg", req.ReorgDepth)
-		if pm.fetcher != nil {
-			pm.fetcher.announce(p, &req)
+		if req.Hash != (common.Hash{}) {
+			if p.announceType == announceTypeNone {
+				return errResp(ErrUnexpectedResponse, "")
+			}
+			if p.announceType == announceTypeSigned {
+				if err := req.checkSignature(p.ID(), update); err != nil {
+					p.Log().Trace("Invalid announcement signature", "err", err)
+					return err
+				}
+				p.Log().Trace("Valid announcement signature")
+			}
+
+			p.Log().Trace("Announce message content", "number", req.Number, "hash", req.Hash, "td", req.Td, "reorg", req.ReorgDepth)
+			if pm.fetcher != nil {
+				pm.fetcher.announce(p, &req)
+			}
 		}
 
 	case GetBlockHeadersMsg:
@@ -432,93 +446,94 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		}
 
 		query := req.Query
-		if reject(query.Amount, MaxHeaderFetch) {
+		if !accept(req.ReqID, query.Amount, MaxHeaderFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
-
-		hashMode := query.Origin.Hash != (common.Hash{})
-		first := true
-		maxNonCanonical := uint64(100)
-
-		// Gather headers until the fetch or network limits is reached
-		var (
-			bytes   common.StorageSize
-			headers []*types.Header
-			unknown bool
-		)
-		for !unknown && len(headers) < int(query.Amount) && bytes < softResponseLimit {
-			// Retrieve the next header satisfying the query
-			var origin *types.Header
-			if hashMode {
-				if first {
-					first = false
-					origin = pm.blockchain.GetHeaderByHash(query.Origin.Hash)
-					if origin != nil {
-						query.Origin.Number = origin.Number.Uint64()
+		go func() {
+			hashMode := query.Origin.Hash != (common.Hash{})
+			first := true
+			maxNonCanonical := uint64(100)
+
+			// Gather headers until the fetch or network limits is reached
+			var (
+				bytes   common.StorageSize
+				headers []*types.Header
+				unknown bool
+			)
+			for !unknown && len(headers) < int(query.Amount) && bytes < softResponseLimit {
+				if !first && !task.waitOrStop() {
+					return
+				}
+				// Retrieve the next header satisfying the query
+				var origin *types.Header
+				if hashMode {
+					if first {
+						origin = pm.blockchain.GetHeaderByHash(query.Origin.Hash)
+						if origin != nil {
+							query.Origin.Number = origin.Number.Uint64()
+						}
+					} else {
+						origin = pm.blockchain.GetHeader(query.Origin.Hash, query.Origin.Number)
 					}
 				} else {
-					origin = pm.blockchain.GetHeader(query.Origin.Hash, query.Origin.Number)
+					origin = pm.blockchain.GetHeaderByNumber(query.Origin.Number)
 				}
-			} else {
-				origin = pm.blockchain.GetHeaderByNumber(query.Origin.Number)
-			}
-			if origin == nil {
-				break
-			}
-			headers = append(headers, origin)
-			bytes += estHeaderRlpSize
-
-			// Advance to the next header of the query
-			switch {
-			case hashMode && query.Reverse:
-				// Hash based traversal towards the genesis block
-				ancestor := query.Skip + 1
-				if ancestor == 0 {
-					unknown = true
-				} else {
-					query.Origin.Hash, query.Origin.Number = pm.blockchain.GetAncestor(query.Origin.Hash, query.Origin.Number, ancestor, &maxNonCanonical)
-					unknown = (query.Origin.Hash == common.Hash{})
+				if origin == nil {
+					break
 				}
-			case hashMode && !query.Reverse:
-				// Hash based traversal towards the leaf block
-				var (
-					current = origin.Number.Uint64()
-					next    = current + query.Skip + 1
-				)
-				if next <= current {
-					infos, _ := json.MarshalIndent(p.Peer.Info(), "", "  ")
-					p.Log().Warn("GetBlockHeaders skip overflow attack", "current", current, "skip", query.Skip, "next", next, "attacker", infos)
-					unknown = true
-				} else {
-					if header := pm.blockchain.GetHeaderByNumber(next); header != nil {
-						nextHash := header.Hash()
-						expOldHash, _ := pm.blockchain.GetAncestor(nextHash, next, query.Skip+1, &maxNonCanonical)
-						if expOldHash == query.Origin.Hash {
-							query.Origin.Hash, query.Origin.Number = nextHash, next
+				headers = append(headers, origin)
+				bytes += estHeaderRlpSize
+
+				// Advance to the next header of the query
+				switch {
+				case hashMode && query.Reverse:
+					// Hash based traversal towards the genesis block
+					ancestor := query.Skip + 1
+					if ancestor == 0 {
+						unknown = true
+					} else {
+						query.Origin.Hash, query.Origin.Number = pm.blockchain.GetAncestor(query.Origin.Hash, query.Origin.Number, ancestor, &maxNonCanonical)
+						unknown = (query.Origin.Hash == common.Hash{})
+					}
+				case hashMode && !query.Reverse:
+					// Hash based traversal towards the leaf block
+					var (
+						current = origin.Number.Uint64()
+						next    = current + query.Skip + 1
+					)
+					if next <= current {
+						infos, _ := json.MarshalIndent(p.Peer.Info(), "", "  ")
+						p.Log().Warn("GetBlockHeaders skip overflow attack", "current", current, "skip", query.Skip, "next", next, "attacker", infos)
+						unknown = true
+					} else {
+						if header := pm.blockchain.GetHeaderByNumber(next); header != nil {
+							nextHash := header.Hash()
+							expOldHash, _ := pm.blockchain.GetAncestor(nextHash, next, query.Skip+1, &maxNonCanonical)
+							if expOldHash == query.Origin.Hash {
+								query.Origin.Hash, query.Origin.Number = nextHash, next
+							} else {
+								unknown = true
+							}
 						} else {
 							unknown = true
 						}
+					}
+				case query.Reverse:
+					// Number based traversal towards the genesis block
+					if query.Origin.Number >= query.Skip+1 {
+						query.Origin.Number -= query.Skip + 1
 					} else {
 						unknown = true
 					}
-				}
-			case query.Reverse:
-				// Number based traversal towards the genesis block
-				if query.Origin.Number >= query.Skip+1 {
-					query.Origin.Number -= query.Skip + 1
-				} else {
-					unknown = true
-				}
 
-			case !query.Reverse:
-				// Number based traversal towards the leaf block
-				query.Origin.Number += query.Skip + 1
+				case !query.Reverse:
+					// Number based traversal towards the leaf block
+					query.Origin.Number += query.Skip + 1
+				}
+				first = false
 			}
-		}
-
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + query.Amount*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, query.Amount, rcost)
-		return p.SendBlockHeaders(req.ReqID, bv, headers)
+			sendResponse(req.ReqID, query.Amount, p.ReplyBlockHeaders(req.ReqID, headers), task.done())
+		}()
 
 	case BlockHeadersMsg:
 		if pm.downloader == nil {
@@ -534,7 +549,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		if pm.fetcher != nil && pm.fetcher.requestedID(resp.ReqID) {
 			pm.fetcher.deliverHeaders(p, resp.ReqID, resp.Headers)
 		} else {
@@ -560,24 +575,27 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			bodies []rlp.RawValue
 		)
 		reqCnt := len(req.Hashes)
-		if reject(uint64(reqCnt), MaxBodyFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxBodyFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
-		for _, hash := range req.Hashes {
-			if bytes >= softResponseLimit {
-				break
-			}
-			// Retrieve the requested block body, stopping if enough was found
-			if number := rawdb.ReadHeaderNumber(pm.chainDb, hash); number != nil {
-				if data := rawdb.ReadBodyRLP(pm.chainDb, hash, *number); len(data) != 0 {
-					bodies = append(bodies, data)
-					bytes += len(data)
+		go func() {
+			for i, hash := range req.Hashes {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				if bytes >= softResponseLimit {
+					break
+				}
+				// Retrieve the requested block body, stopping if enough was found
+				if number := rawdb.ReadHeaderNumber(pm.chainDb, hash); number != nil {
+					if data := rawdb.ReadBodyRLP(pm.chainDb, hash, *number); len(data) != 0 {
+						bodies = append(bodies, data)
+						bytes += len(data)
+					}
 				}
 			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendBlockBodiesRLP(req.ReqID, bv, bodies)
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyBlockBodiesRLP(req.ReqID, bodies), task.done())
+		}()
 
 	case BlockBodiesMsg:
 		if pm.odr == nil {
@@ -593,7 +611,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgBlockBodies,
 			ReqID:   resp.ReqID,
@@ -616,33 +634,36 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			data  [][]byte
 		)
 		reqCnt := len(req.Reqs)
-		if reject(uint64(reqCnt), MaxCodeFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxCodeFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
-		for _, req := range req.Reqs {
-			// Retrieve the requested state entry, stopping if enough was found
-			if number := rawdb.ReadHeaderNumber(pm.chainDb, req.BHash); number != nil {
-				if header := rawdb.ReadHeader(pm.chainDb, req.BHash, *number); header != nil {
-					statedb, err := pm.blockchain.State()
-					if err != nil {
-						continue
-					}
-					account, err := pm.getAccount(statedb, header.Root, common.BytesToHash(req.AccKey))
-					if err != nil {
-						continue
-					}
-					code, _ := statedb.Database().TrieDB().Node(common.BytesToHash(account.CodeHash))
+		go func() {
+			for i, req := range req.Reqs {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				// Retrieve the requested state entry, stopping if enough was found
+				if number := rawdb.ReadHeaderNumber(pm.chainDb, req.BHash); number != nil {
+					if header := rawdb.ReadHeader(pm.chainDb, req.BHash, *number); header != nil {
+						statedb, err := pm.blockchain.State()
+						if err != nil {
+							continue
+						}
+						account, err := pm.getAccount(statedb, header.Root, common.BytesToHash(req.AccKey))
+						if err != nil {
+							continue
+						}
+						code, _ := statedb.Database().TrieDB().Node(common.BytesToHash(account.CodeHash))
 
-					data = append(data, code)
-					if bytes += len(code); bytes >= softResponseLimit {
-						break
+						data = append(data, code)
+						if bytes += len(code); bytes >= softResponseLimit {
+							break
+						}
 					}
 				}
 			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendCode(req.ReqID, bv, data)
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyCode(req.ReqID, data), task.done())
+		}()
 
 	case CodeMsg:
 		if pm.odr == nil {
@@ -658,7 +679,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgCode,
 			ReqID:   resp.ReqID,
@@ -681,34 +702,37 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			receipts []rlp.RawValue
 		)
 		reqCnt := len(req.Hashes)
-		if reject(uint64(reqCnt), MaxReceiptFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxReceiptFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
-		for _, hash := range req.Hashes {
-			if bytes >= softResponseLimit {
-				break
-			}
-			// Retrieve the requested block's receipts, skipping if unknown to us
-			var results types.Receipts
-			if number := rawdb.ReadHeaderNumber(pm.chainDb, hash); number != nil {
-				results = rawdb.ReadReceipts(pm.chainDb, hash, *number)
-			}
-			if results == nil {
-				if header := pm.blockchain.GetHeaderByHash(hash); header == nil || header.ReceiptHash != types.EmptyRootHash {
-					continue
+		go func() {
+			for i, hash := range req.Hashes {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				if bytes >= softResponseLimit {
+					break
+				}
+				// Retrieve the requested block's receipts, skipping if unknown to us
+				var results types.Receipts
+				if number := rawdb.ReadHeaderNumber(pm.chainDb, hash); number != nil {
+					results = rawdb.ReadReceipts(pm.chainDb, hash, *number)
+				}
+				if results == nil {
+					if header := pm.blockchain.GetHeaderByHash(hash); header == nil || header.ReceiptHash != types.EmptyRootHash {
+						continue
+					}
+				}
+				// If known, encode and queue for response packet
+				if encoded, err := rlp.EncodeToBytes(results); err != nil {
+					log.Error("Failed to encode receipt", "err", err)
+				} else {
+					receipts = append(receipts, encoded)
+					bytes += len(encoded)
 				}
 			}
-			// If known, encode and queue for response packet
-			if encoded, err := rlp.EncodeToBytes(results); err != nil {
-				log.Error("Failed to encode receipt", "err", err)
-			} else {
-				receipts = append(receipts, encoded)
-				bytes += len(encoded)
-			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendReceiptsRLP(req.ReqID, bv, receipts)
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyReceiptsRLP(req.ReqID, receipts), task.done())
+		}()
 
 	case ReceiptsMsg:
 		if pm.odr == nil {
@@ -724,7 +748,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgReceipts,
 			ReqID:   resp.ReqID,
@@ -747,42 +771,45 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			proofs proofsData
 		)
 		reqCnt := len(req.Reqs)
-		if reject(uint64(reqCnt), MaxProofsFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxProofsFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
-		for _, req := range req.Reqs {
-			// Retrieve the requested state entry, stopping if enough was found
-			if number := rawdb.ReadHeaderNumber(pm.chainDb, req.BHash); number != nil {
-				if header := rawdb.ReadHeader(pm.chainDb, req.BHash, *number); header != nil {
-					statedb, err := pm.blockchain.State()
-					if err != nil {
-						continue
-					}
-					var trie state.Trie
-					if len(req.AccKey) > 0 {
-						account, err := pm.getAccount(statedb, header.Root, common.BytesToHash(req.AccKey))
+		go func() {
+			for i, req := range req.Reqs {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				// Retrieve the requested state entry, stopping if enough was found
+				if number := rawdb.ReadHeaderNumber(pm.chainDb, req.BHash); number != nil {
+					if header := rawdb.ReadHeader(pm.chainDb, req.BHash, *number); header != nil {
+						statedb, err := pm.blockchain.State()
 						if err != nil {
 							continue
 						}
-						trie, _ = statedb.Database().OpenStorageTrie(common.BytesToHash(req.AccKey), account.Root)
-					} else {
-						trie, _ = statedb.Database().OpenTrie(header.Root)
-					}
-					if trie != nil {
-						var proof light.NodeList
-						trie.Prove(req.Key, 0, &proof)
-
-						proofs = append(proofs, proof)
-						if bytes += proof.DataSize(); bytes >= softResponseLimit {
-							break
+						var trie state.Trie
+						if len(req.AccKey) > 0 {
+							account, err := pm.getAccount(statedb, header.Root, common.BytesToHash(req.AccKey))
+							if err != nil {
+								continue
+							}
+							trie, _ = statedb.Database().OpenStorageTrie(common.BytesToHash(req.AccKey), account.Root)
+						} else {
+							trie, _ = statedb.Database().OpenTrie(header.Root)
+						}
+						if trie != nil {
+							var proof light.NodeList
+							trie.Prove(req.Key, 0, &proof)
+
+							proofs = append(proofs, proof)
+							if bytes += proof.DataSize(); bytes >= softResponseLimit {
+								break
+							}
 						}
 					}
 				}
 			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendProofs(req.ReqID, bv, proofs)
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyProofs(req.ReqID, proofs), task.done())
+		}()
 
 	case GetProofsV2Msg:
 		p.Log().Trace("Received les/2 proofs request")
@@ -801,50 +828,53 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			root      common.Hash
 		)
 		reqCnt := len(req.Reqs)
-		if reject(uint64(reqCnt), MaxProofsFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxProofsFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
+		go func() {
 
-		nodes := light.NewNodeSet()
-
-		for _, req := range req.Reqs {
-			// Look up the state belonging to the request
-			if statedb == nil || req.BHash != lastBHash {
-				statedb, root, lastBHash = nil, common.Hash{}, req.BHash
+			nodes := light.NewNodeSet()
 
-				if number := rawdb.ReadHeaderNumber(pm.chainDb, req.BHash); number != nil {
-					if header := rawdb.ReadHeader(pm.chainDb, req.BHash, *number); header != nil {
-						statedb, _ = pm.blockchain.State()
-						root = header.Root
+			for i, req := range req.Reqs {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				// Look up the state belonging to the request
+				if statedb == nil || req.BHash != lastBHash {
+					statedb, root, lastBHash = nil, common.Hash{}, req.BHash
+
+					if number := rawdb.ReadHeaderNumber(pm.chainDb, req.BHash); number != nil {
+						if header := rawdb.ReadHeader(pm.chainDb, req.BHash, *number); header != nil {
+							statedb, _ = pm.blockchain.State()
+							root = header.Root
+						}
 					}
 				}
-			}
-			if statedb == nil {
-				continue
-			}
-			// Pull the account or storage trie of the request
-			var trie state.Trie
-			if len(req.AccKey) > 0 {
-				account, err := pm.getAccount(statedb, root, common.BytesToHash(req.AccKey))
-				if err != nil {
+				if statedb == nil {
 					continue
 				}
-				trie, _ = statedb.Database().OpenStorageTrie(common.BytesToHash(req.AccKey), account.Root)
-			} else {
-				trie, _ = statedb.Database().OpenTrie(root)
-			}
-			if trie == nil {
-				continue
-			}
-			// Prove the user's request from the account or stroage trie
-			trie.Prove(req.Key, req.FromLevel, nodes)
-			if nodes.DataSize() >= softResponseLimit {
-				break
+				// Pull the account or storage trie of the request
+				var trie state.Trie
+				if len(req.AccKey) > 0 {
+					account, err := pm.getAccount(statedb, root, common.BytesToHash(req.AccKey))
+					if err != nil {
+						continue
+					}
+					trie, _ = statedb.Database().OpenStorageTrie(common.BytesToHash(req.AccKey), account.Root)
+				} else {
+					trie, _ = statedb.Database().OpenTrie(root)
+				}
+				if trie == nil {
+					continue
+				}
+				// Prove the user's request from the account or stroage trie
+				trie.Prove(req.Key, req.FromLevel, nodes)
+				if nodes.DataSize() >= softResponseLimit {
+					break
+				}
 			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendProofsV2(req.ReqID, bv, nodes.NodeList())
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyProofsV2(req.ReqID, nodes.NodeList()), task.done())
+		}()
 
 	case ProofsV1Msg:
 		if pm.odr == nil {
@@ -860,7 +890,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgProofsV1,
 			ReqID:   resp.ReqID,
@@ -881,7 +911,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgProofsV2,
 			ReqID:   resp.ReqID,
@@ -904,34 +934,37 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			proofs []ChtResp
 		)
 		reqCnt := len(req.Reqs)
-		if reject(uint64(reqCnt), MaxHelperTrieProofsFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxHelperTrieProofsFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
-		trieDb := trie.NewDatabase(ethdb.NewTable(pm.chainDb, light.ChtTablePrefix))
-		for _, req := range req.Reqs {
-			if header := pm.blockchain.GetHeaderByNumber(req.BlockNum); header != nil {
-				sectionHead := rawdb.ReadCanonicalHash(pm.chainDb, req.ChtNum*pm.iConfig.ChtSize-1)
-				if root := light.GetChtRoot(pm.chainDb, req.ChtNum-1, sectionHead); root != (common.Hash{}) {
-					trie, err := trie.New(root, trieDb)
-					if err != nil {
-						continue
-					}
-					var encNumber [8]byte
-					binary.BigEndian.PutUint64(encNumber[:], req.BlockNum)
+		go func() {
+			trieDb := trie.NewDatabase(ethdb.NewTable(pm.chainDb, light.ChtTablePrefix))
+			for i, req := range req.Reqs {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				if header := pm.blockchain.GetHeaderByNumber(req.BlockNum); header != nil {
+					sectionHead := rawdb.ReadCanonicalHash(pm.chainDb, req.ChtNum*pm.iConfig.ChtSize-1)
+					if root := light.GetChtRoot(pm.chainDb, req.ChtNum-1, sectionHead); root != (common.Hash{}) {
+						trie, err := trie.New(root, trieDb)
+						if err != nil {
+							continue
+						}
+						var encNumber [8]byte
+						binary.BigEndian.PutUint64(encNumber[:], req.BlockNum)
 
-					var proof light.NodeList
-					trie.Prove(encNumber[:], 0, &proof)
+						var proof light.NodeList
+						trie.Prove(encNumber[:], 0, &proof)
 
-					proofs = append(proofs, ChtResp{Header: header, Proof: proof})
-					if bytes += proof.DataSize() + estHeaderRlpSize; bytes >= softResponseLimit {
-						break
+						proofs = append(proofs, ChtResp{Header: header, Proof: proof})
+						if bytes += proof.DataSize() + estHeaderRlpSize; bytes >= softResponseLimit {
+							break
+						}
 					}
 				}
 			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendHeaderProofs(req.ReqID, bv, proofs)
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyHeaderProofs(req.ReqID, proofs), task.done())
+		}()
 
 	case GetHelperTrieProofsMsg:
 		p.Log().Trace("Received helper trie proof request")
@@ -949,50 +982,53 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			auxData  [][]byte
 		)
 		reqCnt := len(req.Reqs)
-		if reject(uint64(reqCnt), MaxHelperTrieProofsFetch) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxHelperTrieProofsFetch) {
 			return errResp(ErrRequestRejected, "")
 		}
+		go func() {
 
-		var (
-			lastIdx  uint64
-			lastType uint
-			root     common.Hash
-			auxTrie  *trie.Trie
-		)
-		nodes := light.NewNodeSet()
-		for _, req := range req.Reqs {
-			if auxTrie == nil || req.Type != lastType || req.TrieIdx != lastIdx {
-				auxTrie, lastType, lastIdx = nil, req.Type, req.TrieIdx
-
-				var prefix string
-				if root, prefix = pm.getHelperTrie(req.Type, req.TrieIdx); root != (common.Hash{}) {
-					auxTrie, _ = trie.New(root, trie.NewDatabase(ethdb.NewTable(pm.chainDb, prefix)))
-				}
-			}
-			if req.AuxReq == auxRoot {
-				var data []byte
-				if root != (common.Hash{}) {
-					data = root[:]
+			var (
+				lastIdx  uint64
+				lastType uint
+				root     common.Hash
+				auxTrie  *trie.Trie
+			)
+			nodes := light.NewNodeSet()
+			for i, req := range req.Reqs {
+				if i != 0 && !task.waitOrStop() {
+					return
 				}
-				auxData = append(auxData, data)
-				auxBytes += len(data)
-			} else {
-				if auxTrie != nil {
-					auxTrie.Prove(req.Key, req.FromLevel, nodes)
+				if auxTrie == nil || req.Type != lastType || req.TrieIdx != lastIdx {
+					auxTrie, lastType, lastIdx = nil, req.Type, req.TrieIdx
+
+					var prefix string
+					if root, prefix = pm.getHelperTrie(req.Type, req.TrieIdx); root != (common.Hash{}) {
+						auxTrie, _ = trie.New(root, trie.NewDatabase(ethdb.NewTable(pm.chainDb, prefix)))
+					}
 				}
-				if req.AuxReq != 0 {
-					data := pm.getHelperTrieAuxData(req)
+				if req.AuxReq == auxRoot {
+					var data []byte
+					if root != (common.Hash{}) {
+						data = root[:]
+					}
 					auxData = append(auxData, data)
 					auxBytes += len(data)
+				} else {
+					if auxTrie != nil {
+						auxTrie.Prove(req.Key, req.FromLevel, nodes)
+					}
+					if req.AuxReq != 0 {
+						data := pm.getHelperTrieAuxData(req)
+						auxData = append(auxData, data)
+						auxBytes += len(data)
+					}
+				}
+				if nodes.DataSize()+auxBytes >= softResponseLimit {
+					break
 				}
 			}
-			if nodes.DataSize()+auxBytes >= softResponseLimit {
-				break
-			}
-		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-		return p.SendHelperTrieProofs(req.ReqID, bv, HelperTrieResps{Proofs: nodes.NodeList(), AuxData: auxData})
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyHelperTrieProofs(req.ReqID, HelperTrieResps{Proofs: nodes.NodeList(), AuxData: auxData}), task.done())
+		}()
 
 	case HeaderProofsMsg:
 		if pm.odr == nil {
@@ -1007,7 +1043,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 		if err := msg.Decode(&resp); err != nil {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgHeaderProofs,
 			ReqID:   resp.ReqID,
@@ -1028,7 +1064,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
 
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 		deliverMsg = &Msg{
 			MsgType: MsgHelperTrieProofs,
 			ReqID:   resp.ReqID,
@@ -1045,13 +1081,18 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
 		reqCnt := len(txs)
-		if reject(uint64(reqCnt), MaxTxSend) {
+		if !accept(0, uint64(reqCnt), MaxTxSend) {
 			return errResp(ErrRequestRejected, "")
 		}
-		pm.txpool.AddRemotes(txs)
-
-		_, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
+		go func() {
+			for i, tx := range txs {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				pm.txpool.AddRemotes([]*types.Transaction{tx})
+			}
+			sendResponse(0, uint64(reqCnt), nil, task.done())
+		}()
 
 	case SendTxV2Msg:
 		if pm.txpool == nil {
@@ -1066,29 +1107,27 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
 		reqCnt := len(req.Txs)
-		if reject(uint64(reqCnt), MaxTxSend) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxTxSend) {
 			return errResp(ErrRequestRejected, "")
 		}
-
-		hashes := make([]common.Hash, len(req.Txs))
-		for i, tx := range req.Txs {
-			hashes[i] = tx.Hash()
-		}
-		stats := pm.txStatus(hashes)
-		for i, stat := range stats {
-			if stat.Status == core.TxStatusUnknown {
-				if errs := pm.txpool.AddRemotes([]*types.Transaction{req.Txs[i]}); errs[0] != nil {
-					stats[i].Error = errs[0].Error()
-					continue
+		go func() {
+			stats := make([]txStatus, len(req.Txs))
+			for i, tx := range req.Txs {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				hash := tx.Hash()
+				stats[i] = pm.txStatus(hash)
+				if stats[i].Status == core.TxStatusUnknown {
+					if errs := pm.txpool.AddRemotes([]*types.Transaction{tx}); errs[0] != nil {
+						stats[i].Error = errs[0].Error()
+						continue
+					}
+					stats[i] = pm.txStatus(hash)
 				}
-				stats[i] = pm.txStatus([]common.Hash{hashes[i]})[0]
 			}
-		}
-
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-
-		return p.SendTxStatus(req.ReqID, bv, stats)
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyTxStatus(req.ReqID, stats), task.done())
+		}()
 
 	case GetTxStatusMsg:
 		if pm.txpool == nil {
@@ -1103,13 +1142,19 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
 		reqCnt := len(req.Hashes)
-		if reject(uint64(reqCnt), MaxTxStatus) {
+		if !accept(req.ReqID, uint64(reqCnt), MaxTxStatus) {
 			return errResp(ErrRequestRejected, "")
 		}
-		bv, rcost := p.fcClient.RequestProcessed(costs.baseCost + uint64(reqCnt)*costs.reqCost)
-		pm.server.fcCostStats.update(msg.Code, uint64(reqCnt), rcost)
-
-		return p.SendTxStatus(req.ReqID, bv, pm.txStatus(req.Hashes))
+		go func() {
+			stats := make([]txStatus, len(req.Hashes))
+			for i, hash := range req.Hashes {
+				if i != 0 && !task.waitOrStop() {
+					return
+				}
+				stats[i] = pm.txStatus(hash)
+			}
+			sendResponse(req.ReqID, uint64(reqCnt), p.ReplyTxStatus(req.ReqID, stats), task.done())
+		}()
 
 	case TxStatusMsg:
 		if pm.odr == nil {
@@ -1125,7 +1170,7 @@ func (pm *ProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "msg %v: %v", msg, err)
 		}
 
-		p.fcServer.GotReply(resp.ReqID, resp.BV)
+		p.fcServer.ReceivedReply(resp.ReqID, resp.BV)
 
 	default:
 		p.Log().Trace("Received unknown message", "code", msg.Code)
@@ -1185,21 +1230,17 @@ func (pm *ProtocolManager) getHelperTrieAuxData(req HelperTrieReq) []byte {
 	return nil
 }
 
-func (pm *ProtocolManager) txStatus(hashes []common.Hash) []txStatus {
-	stats := make([]txStatus, len(hashes))
-	for i, stat := range pm.txpool.Status(hashes) {
-		// Save the status we've got from the transaction pool
-		stats[i].Status = stat
-
-		// If the transaction is unknown to the pool, try looking it up locally
-		if stat == core.TxStatusUnknown {
-			if tx, blockHash, blockNumber, txIndex := rawdb.ReadTransaction(pm.chainDb, hashes[i]); tx != nil {
-				stats[i].Status = core.TxStatusIncluded
-				stats[i].Lookup = &rawdb.LegacyTxLookupEntry{BlockHash: blockHash, BlockIndex: blockNumber, Index: txIndex}
-			}
+func (pm *ProtocolManager) txStatus(hash common.Hash) txStatus {
+	var stat txStatus
+	stat.Status = pm.txpool.Status([]common.Hash{hash})[0]
+	// If the transaction is unknown to the pool, try looking it up locally
+	if stat.Status == core.TxStatusUnknown {
+		if tx, blockHash, blockNumber, txIndex := rawdb.ReadTransaction(pm.chainDb, hash); tx != nil {
+			stat.Status = core.TxStatusIncluded
+			stat.Lookup = &rawdb.LegacyTxLookupEntry{BlockHash: blockHash, BlockIndex: blockNumber, Index: txIndex}
 		}
 	}
-	return stats
+	return stat
 }
 
 // isULCEnabled returns true if we can use ULC
@@ -1235,7 +1276,7 @@ func (pc *peerConnection) RequestHeadersByHash(origin common.Hash, amount int, s
 		request: func(dp distPeer) func() {
 			peer := dp.(*peer)
 			cost := peer.GetRequestCost(GetBlockHeadersMsg, amount)
-			peer.fcServer.QueueRequest(reqID, cost)
+			peer.fcServer.QueuedRequest(reqID, cost)
 			return func() { peer.RequestHeadersByHash(reqID, cost, origin, amount, skip, reverse) }
 		},
 	}
@@ -1259,7 +1300,7 @@ func (pc *peerConnection) RequestHeadersByNumber(origin uint64, amount int, skip
 		request: func(dp distPeer) func() {
 			peer := dp.(*peer)
 			cost := peer.GetRequestCost(GetBlockHeadersMsg, amount)
-			peer.fcServer.QueueRequest(reqID, cost)
+			peer.fcServer.QueuedRequest(reqID, cost)
 			return func() { peer.RequestHeadersByNumber(reqID, cost, origin, amount, skip, reverse) }
 		},
 	}
diff --git a/les/helper_test.go b/les/helper_test.go
index 02b1668c8..a8097708e 100644
--- a/les/helper_test.go
+++ b/les/helper_test.go
@@ -27,6 +27,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus/ethash"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -133,16 +134,6 @@ func testIndexers(db ethdb.Database, odr light.OdrBackend, iConfig *light.Indexe
 	return chtIndexer, bloomIndexer, bloomTrieIndexer
 }
 
-func testRCL() RequestCostList {
-	cl := make(RequestCostList, len(reqList))
-	for i, code := range reqList {
-		cl[i].MsgCode = code
-		cl[i].BaseCost = 0
-		cl[i].ReqCost = 0
-	}
-	return cl
-}
-
 // newTestProtocolManager creates a new protocol manager for testing purposes,
 // with the given number of blocks already known, potential notification
 // channels for different events and relative chain indexers array.
@@ -183,14 +174,14 @@ func newTestProtocolManager(lightSync bool, blocks int, generator func(int, *cor
 	if !lightSync {
 		srv := &LesServer{lesCommons: lesCommons{protocolManager: pm}}
 		pm.server = srv
+		pm.servingQueue.setThreads(4)
 
-		srv.defParams = &flowcontrol.ServerParams{
+		srv.defParams = flowcontrol.ServerParams{
 			BufLimit:    testBufLimit,
 			MinRecharge: 1,
 		}
 
-		srv.fcManager = flowcontrol.NewClientManager(50, 10, 1000000000)
-		srv.fcCostStats = newCostStats(nil)
+		srv.fcManager = flowcontrol.NewClientManager(nil, &mclock.System{})
 	}
 	pm.Start(1000)
 	return pm, nil
@@ -304,7 +295,7 @@ func (p *testPeer) handshake(t *testing.T, td *big.Int, head common.Hash, headNu
 	expList = expList.add("txRelay", nil)
 	expList = expList.add("flowControl/BL", testBufLimit)
 	expList = expList.add("flowControl/MRR", uint64(1))
-	expList = expList.add("flowControl/MRC", testRCL())
+	expList = expList.add("flowControl/MRC", testCostList())
 
 	if err := p2p.ExpectMsg(p.app, StatusMsg, expList); err != nil {
 		t.Fatalf("status recv: %v", err)
@@ -313,7 +304,7 @@ func (p *testPeer) handshake(t *testing.T, td *big.Int, head common.Hash, headNu
 		t.Fatalf("status send: %v", err)
 	}
 
-	p.fcServerParams = &flowcontrol.ServerParams{
+	p.fcParams = flowcontrol.ServerParams{
 		BufLimit:    testBufLimit,
 		MinRecharge: 1,
 	}
@@ -375,7 +366,7 @@ func newClientServerEnv(t *testing.T, blocks int, protocol int, waitIndexers fun
 	db, ldb := ethdb.NewMemDatabase(), ethdb.NewMemDatabase()
 	peers, lPeers := newPeerSet(), newPeerSet()
 
-	dist := newRequestDistributor(lPeers, make(chan struct{}))
+	dist := newRequestDistributor(lPeers, make(chan struct{}), &mclock.System{})
 	rm := newRetrieveManager(lPeers, dist, nil)
 	odr := NewLesOdr(ldb, light.TestClientIndexerConfig, rm)
 
diff --git a/les/odr.go b/les/odr.go
index f7592354d..5d98c66a9 100644
--- a/les/odr.go
+++ b/les/odr.go
@@ -117,7 +117,7 @@ func (odr *LesOdr) Retrieve(ctx context.Context, req light.OdrRequest) (err erro
 		request: func(dp distPeer) func() {
 			p := dp.(*peer)
 			cost := lreq.GetCost(p)
-			p.fcServer.QueueRequest(reqID, cost)
+			p.fcServer.QueuedRequest(reqID, cost)
 			return func() { lreq.Request(reqID, p) }
 		},
 	}
diff --git a/les/odr_requests.go b/les/odr_requests.go
index 0f2e5dd9e..7b7876762 100644
--- a/les/odr_requests.go
+++ b/les/odr_requests.go
@@ -14,8 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package light implements on-demand retrieval capable state and chain objects
-// for the Ethereum Light Client.
 package les
 
 import (
diff --git a/les/peer.go b/les/peer.go
index 9ae94b20f..8b506de62 100644
--- a/les/peer.go
+++ b/les/peer.go
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
@@ -25,6 +24,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth"
 	"github.com/ethereum/go-ethereum/les/flowcontrol"
@@ -42,6 +42,17 @@ var (
 
 const maxResponseErrors = 50 // number of invalid responses tolerated (makes the protocol less brittle but still avoids spam)
 
+// capacity limitation for parameter updates
+const (
+	allowedUpdateBytes = 100000                // initial/maximum allowed update size
+	allowedUpdateRate  = time.Millisecond * 10 // time constant for recharging one byte of allowance
+)
+
+// if the total encoded size of a sent transaction batch is over txSizeCostLimit
+// per transaction then the request cost is calculated as proportional to the
+// encoded size instead of the transaction count
+const txSizeCostLimit = 0x10000
+
 const (
 	announceTypeNone = iota
 	announceTypeSimple
@@ -63,17 +74,24 @@ type peer struct {
 	headInfo *announceData
 	lock     sync.RWMutex
 
-	announceChn chan announceData
-	sendQueue   *execQueue
+	sendQueue *execQueue
+
+	errCh chan error
+	// responseLock ensures that responses are queued in the same order as
+	// RequestProcessed is called
+	responseLock  sync.Mutex
+	responseCount uint64
 
 	poolEntry      *poolEntry
 	hasBlock       func(common.Hash, uint64, bool) bool
 	responseErrors int
+	updateCounter  uint64
+	updateTime     mclock.AbsTime
 
-	fcClient       *flowcontrol.ClientNode // nil if the peer is server only
-	fcServer       *flowcontrol.ServerNode // nil if the peer is client only
-	fcServerParams *flowcontrol.ServerParams
-	fcCosts        requestCostTable
+	fcClient *flowcontrol.ClientNode // nil if the peer is server only
+	fcServer *flowcontrol.ServerNode // nil if the peer is client only
+	fcParams flowcontrol.ServerParams
+	fcCosts  requestCostTable
 
 	isTrusted      bool
 	isOnlyAnnounce bool
@@ -83,14 +101,34 @@ func newPeer(version int, network uint64, isTrusted bool, p *p2p.Peer, rw p2p.Ms
 	id := p.ID()
 
 	return &peer{
-		Peer:        p,
-		rw:          rw,
-		version:     version,
-		network:     network,
-		id:          fmt.Sprintf("%x", id[:8]),
-		announceChn: make(chan announceData, 20),
-		isTrusted:   isTrusted,
+		Peer:      p,
+		rw:        rw,
+		version:   version,
+		network:   network,
+		id:        fmt.Sprintf("%x", id),
+		isTrusted: isTrusted,
+	}
+}
+
+// rejectUpdate returns true if a parameter update has to be rejected because
+// the size and/or rate of updates exceed the capacity limitation
+func (p *peer) rejectUpdate(size uint64) bool {
+	now := mclock.Now()
+	if p.updateCounter == 0 {
+		p.updateTime = now
+	} else {
+		dt := now - p.updateTime
+		r := uint64(dt / mclock.AbsTime(allowedUpdateRate))
+		if p.updateCounter > r {
+			p.updateCounter -= r
+			p.updateTime += mclock.AbsTime(allowedUpdateRate * time.Duration(r))
+		} else {
+			p.updateCounter = 0
+			p.updateTime = now
+		}
 	}
+	p.updateCounter += size
+	return p.updateCounter > allowedUpdateBytes
 }
 
 func (p *peer) canQueue() bool {
@@ -147,6 +185,20 @@ func (p *peer) waitBefore(maxCost uint64) (time.Duration, float64) {
 	return p.fcServer.CanSend(maxCost)
 }
 
+// updateCapacity updates the request serving capacity assigned to a given client
+// and also sends an announcement about the updated flow control parameters
+func (p *peer) updateCapacity(cap uint64) {
+	p.responseLock.Lock()
+	defer p.responseLock.Unlock()
+
+	p.fcParams = flowcontrol.ServerParams{MinRecharge: cap, BufLimit: cap * bufLimitRatio}
+	p.fcClient.UpdateParams(p.fcParams)
+	var kvList keyValueList
+	kvList = kvList.add("flowControl/MRR", cap)
+	kvList = kvList.add("flowControl/BL", cap*bufLimitRatio)
+	p.queueSend(func() { p.SendAnnounce(announceData{Update: kvList}) })
+}
+
 func sendRequest(w p2p.MsgWriter, msgcode, reqID, cost uint64, data interface{}) error {
 	type req struct {
 		ReqID uint64
@@ -155,12 +207,27 @@ func sendRequest(w p2p.MsgWriter, msgcode, reqID, cost uint64, data interface{})
 	return p2p.Send(w, msgcode, req{reqID, data})
 }
 
-func sendResponse(w p2p.MsgWriter, msgcode, reqID, bv uint64, data interface{}) error {
+// reply struct represents a reply with the actual data already RLP encoded and
+// only the bv (buffer value) missing. This allows the serving mechanism to
+// calculate the bv value which depends on the data size before sending the reply.
+type reply struct {
+	w              p2p.MsgWriter
+	msgcode, reqID uint64
+	data           rlp.RawValue
+}
+
+// send sends the reply with the calculated buffer value
+func (r *reply) send(bv uint64) error {
 	type resp struct {
 		ReqID, BV uint64
-		Data      interface{}
+		Data      rlp.RawValue
 	}
-	return p2p.Send(w, msgcode, resp{reqID, bv, data})
+	return p2p.Send(r.w, r.msgcode, resp{r.reqID, bv, r.data})
+}
+
+// size returns the RLP encoded size of the message data
+func (r *reply) size() uint32 {
+	return uint32(len(r.data))
 }
 
 func (p *peer) GetRequestCost(msgcode uint64, amount int) uint64 {
@@ -168,8 +235,34 @@ func (p *peer) GetRequestCost(msgcode uint64, amount int) uint64 {
 	defer p.lock.RUnlock()
 
 	cost := p.fcCosts[msgcode].baseCost + p.fcCosts[msgcode].reqCost*uint64(amount)
-	if cost > p.fcServerParams.BufLimit {
-		cost = p.fcServerParams.BufLimit
+	if cost > p.fcParams.BufLimit {
+		cost = p.fcParams.BufLimit
+	}
+	return cost
+}
+
+func (p *peer) GetTxRelayCost(amount, size int) uint64 {
+	p.lock.RLock()
+	defer p.lock.RUnlock()
+
+	var msgcode uint64
+	switch p.version {
+	case lpv1:
+		msgcode = SendTxMsg
+	case lpv2:
+		msgcode = SendTxV2Msg
+	default:
+		panic(nil)
+	}
+
+	cost := p.fcCosts[msgcode].baseCost + p.fcCosts[msgcode].reqCost*uint64(amount)
+	sizeCost := p.fcCosts[msgcode].baseCost + p.fcCosts[msgcode].reqCost*uint64(size)/txSizeCostLimit
+	if sizeCost > cost {
+		cost = sizeCost
+	}
+
+	if cost > p.fcParams.BufLimit {
+		cost = p.fcParams.BufLimit
 	}
 	return cost
 }
@@ -188,52 +281,61 @@ func (p *peer) SendAnnounce(request announceData) error {
 	return p2p.Send(p.rw, AnnounceMsg, request)
 }
 
-// SendBlockHeaders sends a batch of block headers to the remote peer.
-func (p *peer) SendBlockHeaders(reqID, bv uint64, headers []*types.Header) error {
-	return sendResponse(p.rw, BlockHeadersMsg, reqID, bv, headers)
+// ReplyBlockHeaders creates a reply with a batch of block headers
+func (p *peer) ReplyBlockHeaders(reqID uint64, headers []*types.Header) *reply {
+	data, _ := rlp.EncodeToBytes(headers)
+	return &reply{p.rw, BlockHeadersMsg, reqID, data}
 }
 
-// SendBlockBodiesRLP sends a batch of block contents to the remote peer from
+// ReplyBlockBodiesRLP creates a reply with a batch of block contents from
 // an already RLP encoded format.
-func (p *peer) SendBlockBodiesRLP(reqID, bv uint64, bodies []rlp.RawValue) error {
-	return sendResponse(p.rw, BlockBodiesMsg, reqID, bv, bodies)
+func (p *peer) ReplyBlockBodiesRLP(reqID uint64, bodies []rlp.RawValue) *reply {
+	data, _ := rlp.EncodeToBytes(bodies)
+	return &reply{p.rw, BlockBodiesMsg, reqID, data}
 }
 
-// SendCodeRLP sends a batch of arbitrary internal data, corresponding to the
+// ReplyCode creates a reply with a batch of arbitrary internal data, corresponding to the
 // hashes requested.
-func (p *peer) SendCode(reqID, bv uint64, data [][]byte) error {
-	return sendResponse(p.rw, CodeMsg, reqID, bv, data)
+func (p *peer) ReplyCode(reqID uint64, codes [][]byte) *reply {
+	data, _ := rlp.EncodeToBytes(codes)
+	return &reply{p.rw, CodeMsg, reqID, data}
 }
 
-// SendReceiptsRLP sends a batch of transaction receipts, corresponding to the
+// ReplyReceiptsRLP creates a reply with a batch of transaction receipts, corresponding to the
 // ones requested from an already RLP encoded format.
-func (p *peer) SendReceiptsRLP(reqID, bv uint64, receipts []rlp.RawValue) error {
-	return sendResponse(p.rw, ReceiptsMsg, reqID, bv, receipts)
+func (p *peer) ReplyReceiptsRLP(reqID uint64, receipts []rlp.RawValue) *reply {
+	data, _ := rlp.EncodeToBytes(receipts)
+	return &reply{p.rw, ReceiptsMsg, reqID, data}
 }
 
-// SendProofs sends a batch of legacy LES/1 merkle proofs, corresponding to the ones requested.
-func (p *peer) SendProofs(reqID, bv uint64, proofs proofsData) error {
-	return sendResponse(p.rw, ProofsV1Msg, reqID, bv, proofs)
+// ReplyProofs creates a reply with a batch of legacy LES/1 merkle proofs, corresponding to the ones requested.
+func (p *peer) ReplyProofs(reqID uint64, proofs proofsData) *reply {
+	data, _ := rlp.EncodeToBytes(proofs)
+	return &reply{p.rw, ProofsV1Msg, reqID, data}
 }
 
-// SendProofsV2 sends a batch of merkle proofs, corresponding to the ones requested.
-func (p *peer) SendProofsV2(reqID, bv uint64, proofs light.NodeList) error {
-	return sendResponse(p.rw, ProofsV2Msg, reqID, bv, proofs)
+// ReplyProofsV2 creates a reply with a batch of merkle proofs, corresponding to the ones requested.
+func (p *peer) ReplyProofsV2(reqID uint64, proofs light.NodeList) *reply {
+	data, _ := rlp.EncodeToBytes(proofs)
+	return &reply{p.rw, ProofsV2Msg, reqID, data}
 }
 
-// SendHeaderProofs sends a batch of legacy LES/1 header proofs, corresponding to the ones requested.
-func (p *peer) SendHeaderProofs(reqID, bv uint64, proofs []ChtResp) error {
-	return sendResponse(p.rw, HeaderProofsMsg, reqID, bv, proofs)
+// ReplyHeaderProofs creates a reply with a batch of legacy LES/1 header proofs, corresponding to the ones requested.
+func (p *peer) ReplyHeaderProofs(reqID uint64, proofs []ChtResp) *reply {
+	data, _ := rlp.EncodeToBytes(proofs)
+	return &reply{p.rw, HeaderProofsMsg, reqID, data}
 }
 
-// SendHelperTrieProofs sends a batch of HelperTrie proofs, corresponding to the ones requested.
-func (p *peer) SendHelperTrieProofs(reqID, bv uint64, resp HelperTrieResps) error {
-	return sendResponse(p.rw, HelperTrieProofsMsg, reqID, bv, resp)
+// ReplyHelperTrieProofs creates a reply with a batch of HelperTrie proofs, corresponding to the ones requested.
+func (p *peer) ReplyHelperTrieProofs(reqID uint64, resp HelperTrieResps) *reply {
+	data, _ := rlp.EncodeToBytes(resp)
+	return &reply{p.rw, HelperTrieProofsMsg, reqID, data}
 }
 
-// SendTxStatus sends a batch of transaction status records, corresponding to the ones requested.
-func (p *peer) SendTxStatus(reqID, bv uint64, stats []txStatus) error {
-	return sendResponse(p.rw, TxStatusMsg, reqID, bv, stats)
+// ReplyTxStatus creates a reply with a batch of transaction status records, corresponding to the ones requested.
+func (p *peer) ReplyTxStatus(reqID uint64, stats []txStatus) *reply {
+	data, _ := rlp.EncodeToBytes(stats)
+	return &reply{p.rw, TxStatusMsg, reqID, data}
 }
 
 // RequestHeadersByHash fetches a batch of blocks' headers corresponding to the
@@ -311,9 +413,9 @@ func (p *peer) RequestTxStatus(reqID, cost uint64, txHashes []common.Hash) error
 	return sendRequest(p.rw, GetTxStatusMsg, reqID, cost, txHashes)
 }
 
-// SendTxStatus sends a batch of transactions to be added to the remote transaction pool.
-func (p *peer) SendTxs(reqID, cost uint64, txs types.Transactions) error {
-	p.Log().Debug("Fetching batch of transactions", "count", len(txs))
+// SendTxStatus creates a reply with a batch of transactions to be added to the remote transaction pool.
+func (p *peer) SendTxs(reqID, cost uint64, txs rlp.RawValue) error {
+	p.Log().Debug("Sending batch of transactions", "size", len(txs))
 	switch p.version {
 	case lpv1:
 		return p2p.Send(p.rw, SendTxMsg, txs) // old message format does not include reqID
@@ -344,12 +446,14 @@ func (l keyValueList) add(key string, val interface{}) keyValueList {
 	return append(l, entry)
 }
 
-func (l keyValueList) decode() keyValueMap {
+func (l keyValueList) decode() (keyValueMap, uint64) {
 	m := make(keyValueMap)
+	var size uint64
 	for _, entry := range l {
 		m[entry.Key] = entry.Value
+		size += uint64(len(entry.Key)) + uint64(len(entry.Value)) + 8
 	}
-	return m
+	return m, size
 }
 
 func (m keyValueMap) get(key string, val interface{}) error {
@@ -414,9 +518,15 @@ func (p *peer) Handshake(td *big.Int, head common.Hash, headNum uint64, genesis
 		}
 		send = send.add("flowControl/BL", server.defParams.BufLimit)
 		send = send.add("flowControl/MRR", server.defParams.MinRecharge)
-		list := server.fcCostStats.getCurrentList()
-		send = send.add("flowControl/MRC", list)
-		p.fcCosts = list.decode()
+		var costList RequestCostList
+		if server.costTracker != nil {
+			costList = server.costTracker.makeCostList()
+		} else {
+			costList = testCostList()
+		}
+		send = send.add("flowControl/MRC", costList)
+		p.fcCosts = costList.decode()
+		p.fcParams = server.defParams
 	} else {
 		//on client node
 		p.announceType = announceTypeSimple
@@ -430,8 +540,10 @@ func (p *peer) Handshake(td *big.Int, head common.Hash, headNum uint64, genesis
 	if err != nil {
 		return err
 	}
-
-	recv := recvList.decode()
+	recv, size := recvList.decode()
+	if p.rejectUpdate(size) {
+		return errResp(ErrRequestRejected, "")
+	}
 
 	var rGenesis, rHash common.Hash
 	var rVersion, rNetwork, rNum uint64
@@ -492,7 +604,7 @@ func (p *peer) Handshake(td *big.Int, head common.Hash, headNum uint64, genesis
 			return errResp(ErrUselessPeer, "peer cannot serve requests")
 		}
 
-		params := &flowcontrol.ServerParams{}
+		var params flowcontrol.ServerParams
 		if err := recv.get("flowControl/BL", &params.BufLimit); err != nil {
 			return err
 		}
@@ -503,14 +615,38 @@ func (p *peer) Handshake(td *big.Int, head common.Hash, headNum uint64, genesis
 		if err := recv.get("flowControl/MRC", &MRC); err != nil {
 			return err
 		}
-		p.fcServerParams = params
-		p.fcServer = flowcontrol.NewServerNode(params)
+		p.fcParams = params
+		p.fcServer = flowcontrol.NewServerNode(params, &mclock.System{})
 		p.fcCosts = MRC.decode()
 	}
 	p.headInfo = &announceData{Td: rTd, Hash: rHash, Number: rNum}
 	return nil
 }
 
+// updateFlowControl updates the flow control parameters belonging to the server
+// node if the announced key/value set contains relevant fields
+func (p *peer) updateFlowControl(update keyValueMap) {
+	if p.fcServer == nil {
+		return
+	}
+	params := p.fcParams
+	updateParams := false
+	if update.get("flowControl/BL", &params.BufLimit) == nil {
+		updateParams = true
+	}
+	if update.get("flowControl/MRR", &params.MinRecharge) == nil {
+		updateParams = true
+	}
+	if updateParams {
+		p.fcParams = params
+		p.fcServer.UpdateParams(params)
+	}
+	var MRC RequestCostList
+	if update.get("flowControl/MRC", &MRC) == nil {
+		p.fcCosts = MRC.decode()
+	}
+}
+
 // String implements fmt.Stringer.
 func (p *peer) String() string {
 	return fmt.Sprintf("Peer %s [%s]", p.id,
diff --git a/les/peer_test.go b/les/peer_test.go
index a0e0a300c..8b12dd291 100644
--- a/les/peer_test.go
+++ b/les/peer_test.go
@@ -5,6 +5,7 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/les/flowcontrol"
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/rlp"
@@ -34,7 +35,7 @@ func TestPeerHandshakeSetAnnounceTypeToAnnounceTypeSignedForTrustedPeer(t *testi
 		rw: &rwStub{
 			WriteHook: func(recvList keyValueList) {
 				//checking that ulc sends to peer allowedRequests=onlyAnnounceRequests and announceType = announceTypeSigned
-				recv := recvList.decode()
+				recv, _ := recvList.decode()
 				var reqType uint64
 
 				err := recv.get("announceType", &reqType)
@@ -79,7 +80,7 @@ func TestPeerHandshakeAnnounceTypeSignedForTrustedPeersPeerNotInTrusted(t *testi
 		rw: &rwStub{
 			WriteHook: func(recvList keyValueList) {
 				//checking that ulc sends to peer allowedRequests=noRequests and announceType != announceTypeSigned
-				recv := recvList.decode()
+				recv, _ := recvList.decode()
 				var reqType uint64
 
 				err := recv.get("announceType", &reqType)
@@ -237,17 +238,11 @@ func TestPeerHandshakeClientReturnErrorOnUselessPeer(t *testing.T) {
 
 func generateLesServer() *LesServer {
 	s := &LesServer{
-		defParams: &flowcontrol.ServerParams{
+		defParams: flowcontrol.ServerParams{
 			BufLimit:    uint64(300000000),
 			MinRecharge: uint64(50000),
 		},
-		fcManager: flowcontrol.NewClientManager(1, 2, 3),
-		fcCostStats: &requestCostStats{
-			stats: make(map[uint64]*linReg, len(reqList)),
-		},
-	}
-	for _, code := range reqList {
-		s.fcCostStats.stats[code] = &linReg{cnt: 100}
+		fcManager: flowcontrol.NewClientManager(nil, &mclock.System{}),
 	}
 	return s
 }
diff --git a/les/protocol.go b/les/protocol.go
index b75f92bf7..65395ac05 100644
--- a/les/protocol.go
+++ b/les/protocol.go
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
@@ -81,6 +80,25 @@ const (
 	TxStatusMsg            = 0x15
 )
 
+type requestInfo struct {
+	name     string
+	maxCount uint64
+}
+
+var requests = map[uint64]requestInfo{
+	GetBlockHeadersMsg:     {"GetBlockHeaders", MaxHeaderFetch},
+	GetBlockBodiesMsg:      {"GetBlockBodies", MaxBodyFetch},
+	GetReceiptsMsg:         {"GetReceipts", MaxReceiptFetch},
+	GetProofsV1Msg:         {"GetProofsV1", MaxProofsFetch},
+	GetCodeMsg:             {"GetCode", MaxCodeFetch},
+	SendTxMsg:              {"SendTx", MaxTxSend},
+	GetHeaderProofsMsg:     {"GetHeaderProofs", MaxHelperTrieProofsFetch},
+	GetProofsV2Msg:         {"GetProofsV2", MaxProofsFetch},
+	GetHelperTrieProofsMsg: {"GetHelperTrieProofs", MaxHelperTrieProofsFetch},
+	SendTxV2Msg:            {"SendTxV2", MaxTxSend},
+	GetTxStatusMsg:         {"GetTxStatus", MaxTxStatus},
+}
+
 type errCode int
 
 const (
@@ -146,9 +164,9 @@ func (a *announceData) sign(privKey *ecdsa.PrivateKey) {
 }
 
 // checkSignature verifies if the block announcement has a valid signature by the given pubKey
-func (a *announceData) checkSignature(id enode.ID) error {
+func (a *announceData) checkSignature(id enode.ID, update keyValueMap) error {
 	var sig []byte
-	if err := a.Update.decode().get("sign", &sig); err != nil {
+	if err := update.get("sign", &sig); err != nil {
 		return err
 	}
 	rlp, _ := rlp.EncodeToBytes(announceBlock{a.Hash, a.Number, a.Td})
diff --git a/les/randselect.go b/les/randselect.go
index 1cc1d3d3e..8efe0c94d 100644
--- a/les/randselect.go
+++ b/les/randselect.go
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
diff --git a/les/retrieve.go b/les/retrieve.go
index d77cfea74..dd9d14598 100644
--- a/les/retrieve.go
+++ b/les/retrieve.go
@@ -14,8 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package light implements on-demand retrieval capable state and chain objects
-// for the Ethereum Light Client.
 package les
 
 import (
diff --git a/les/server.go b/les/server.go
index 2ded3c184..270640f02 100644
--- a/les/server.go
+++ b/les/server.go
@@ -14,40 +14,46 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
 	"crypto/ecdsa"
-	"encoding/binary"
-	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/rawdb"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth"
-	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/les/flowcontrol"
 	"github.com/ethereum/go-ethereum/light"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/discv5"
 	"github.com/ethereum/go-ethereum/params"
-	"github.com/ethereum/go-ethereum/rlp"
+	"github.com/ethereum/go-ethereum/rpc"
 )
 
+const bufLimitRatio = 6000 // fixed bufLimit/MRR ratio
+
 type LesServer struct {
 	lesCommons
 
 	fcManager    *flowcontrol.ClientManager // nil if our node is client only
-	fcCostStats  *requestCostStats
-	defParams    *flowcontrol.ServerParams
+	costTracker  *costTracker
+	defParams    flowcontrol.ServerParams
 	lesTopics    []discv5.Topic
 	privateKey   *ecdsa.PrivateKey
 	quitSync     chan struct{}
 	onlyAnnounce bool
+
+	thcNormal, thcBlockProcessing int // serving thread count for normal operation and block processing mode
+
+	maxPeers           int
+	freeClientCap      uint64
+	freeClientPool     *freeClientPool
+	priorityClientPool *priorityClientPool
 }
 
 func NewLesServer(eth *eth.Ethereum, config *eth.Config) (*LesServer, error) {
@@ -87,12 +93,20 @@ func NewLesServer(eth *eth.Ethereum, config *eth.Config) (*LesServer, error) {
 			bloomTrieIndexer: light.NewBloomTrieIndexer(eth.ChainDb(), nil, params.BloomBitsBlocks, params.BloomTrieFrequency),
 			protocolManager:  pm,
 		},
+		costTracker:  newCostTracker(eth.ChainDb(), config),
 		quitSync:     quitSync,
 		lesTopics:    lesTopics,
 		onlyAnnounce: config.OnlyAnnounce,
 	}
 
 	logger := log.New()
+	pm.server = srv
+	srv.thcNormal = config.LightServ * 4 / 100
+	if srv.thcNormal < 4 {
+		srv.thcNormal = 4
+	}
+	srv.thcBlockProcessing = config.LightServ/100 + 1
+	srv.fcManager = flowcontrol.NewClientManager(nil, &mclock.System{})
 
 	chtV1SectionCount, _, _ := srv.chtIndexer.Sections() // indexer still uses LES/1 4k section size for backwards server compatibility
 	chtV2SectionCount := chtV1SectionCount / (params.CHTFrequencyClient / params.CHTFrequencyServer)
@@ -114,15 +128,60 @@ func NewLesServer(eth *eth.Ethereum, config *eth.Config) (*LesServer, error) {
 	}
 
 	srv.chtIndexer.Start(eth.BlockChain())
-	pm.server = srv
+	return srv, nil
+}
 
-	srv.defParams = &flowcontrol.ServerParams{
-		BufLimit:    300000000,
-		MinRecharge: 50000,
+func (s *LesServer) APIs() []rpc.API {
+	return []rpc.API{
+		{
+			Namespace: "les",
+			Version:   "1.0",
+			Service:   NewPrivateLightServerAPI(s),
+			Public:    false,
+		},
 	}
-	srv.fcManager = flowcontrol.NewClientManager(uint64(config.LightServ), 10, 1000000000)
-	srv.fcCostStats = newCostStats(eth.ChainDb())
-	return srv, nil
+}
+
+// startEventLoop starts an event handler loop that updates the recharge curve of
+// the client manager and adjusts the client pool's size according to the total
+// capacity updates coming from the client manager
+func (s *LesServer) startEventLoop() {
+	s.protocolManager.wg.Add(1)
+
+	var processing bool
+	blockProcFeed := make(chan bool, 100)
+	s.protocolManager.blockchain.(*core.BlockChain).SubscribeBlockProcessingEvent(blockProcFeed)
+	totalRechargeCh := make(chan uint64, 100)
+	totalRecharge := s.costTracker.subscribeTotalRecharge(totalRechargeCh)
+	totalCapacityCh := make(chan uint64, 100)
+	updateRecharge := func() {
+		if processing {
+			s.protocolManager.servingQueue.setThreads(s.thcBlockProcessing)
+			s.fcManager.SetRechargeCurve(flowcontrol.PieceWiseLinear{{0, 0}, {totalRecharge, totalRecharge}})
+		} else {
+			s.protocolManager.servingQueue.setThreads(s.thcNormal)
+			s.fcManager.SetRechargeCurve(flowcontrol.PieceWiseLinear{{0, 0}, {totalRecharge / 10, totalRecharge}, {totalRecharge, totalRecharge}})
+		}
+	}
+	updateRecharge()
+	totalCapacity := s.fcManager.SubscribeTotalCapacity(totalCapacityCh)
+	s.priorityClientPool.setLimits(s.maxPeers, totalCapacity)
+
+	go func() {
+		for {
+			select {
+			case processing = <-blockProcFeed:
+				updateRecharge()
+			case totalRecharge = <-totalRechargeCh:
+				updateRecharge()
+			case totalCapacity = <-totalCapacityCh:
+				s.priorityClientPool.setLimits(s.maxPeers, totalCapacity)
+			case <-s.protocolManager.quitSync:
+				s.protocolManager.wg.Done()
+				return
+			}
+		}
+	}()
 }
 
 func (s *LesServer) Protocols() []p2p.Protocol {
@@ -131,6 +190,30 @@ func (s *LesServer) Protocols() []p2p.Protocol {
 
 // Start starts the LES server
 func (s *LesServer) Start(srvr *p2p.Server) {
+	s.maxPeers = s.config.LightPeers
+	totalRecharge := s.costTracker.totalRecharge()
+	if s.maxPeers > 0 {
+		s.freeClientCap = minCapacity //totalRecharge / uint64(s.maxPeers)
+		if s.freeClientCap < minCapacity {
+			s.freeClientCap = minCapacity
+		}
+		if s.freeClientCap > 0 {
+			s.defParams = flowcontrol.ServerParams{
+				BufLimit:    s.freeClientCap * bufLimitRatio,
+				MinRecharge: s.freeClientCap,
+			}
+		}
+	}
+	freePeers := int(totalRecharge / s.freeClientCap)
+	if freePeers < s.maxPeers {
+		log.Warn("Light peer count limited", "specified", s.maxPeers, "allowed", freePeers)
+	}
+
+	s.freeClientPool = newFreeClientPool(s.chainDb, s.freeClientCap, 10000, mclock.System{}, func(id string) { go s.protocolManager.removePeer(id) })
+	s.priorityClientPool = newPriorityClientPool(s.freeClientCap, s.protocolManager.peers, s.freeClientPool)
+
+	s.protocolManager.peers.notify(s.priorityClientPool)
+	s.startEventLoop()
 	s.protocolManager.Start(s.config.LightPeers)
 	if srvr.DiscV5 != nil {
 		for _, topic := range s.lesTopics {
@@ -156,185 +239,14 @@ func (s *LesServer) SetBloomBitsIndexer(bloomIndexer *core.ChainIndexer) {
 func (s *LesServer) Stop() {
 	s.chtIndexer.Close()
 	// bloom trie indexer is closed by parent bloombits indexer
-	s.fcCostStats.store()
-	s.fcManager.Stop()
 	go func() {
 		<-s.protocolManager.noMorePeers
 	}()
+	s.freeClientPool.stop()
+	s.costTracker.stop()
 	s.protocolManager.Stop()
 }
 
-type requestCosts struct {
-	baseCost, reqCost uint64
-}
-
-type requestCostTable map[uint64]*requestCosts
-
-type RequestCostList []struct {
-	MsgCode, BaseCost, ReqCost uint64
-}
-
-func (list RequestCostList) decode() requestCostTable {
-	table := make(requestCostTable)
-	for _, e := range list {
-		table[e.MsgCode] = &requestCosts{
-			baseCost: e.BaseCost,
-			reqCost:  e.ReqCost,
-		}
-	}
-	return table
-}
-
-type linReg struct {
-	sumX, sumY, sumXX, sumXY float64
-	cnt                      uint64
-}
-
-const linRegMaxCnt = 100000
-
-func (l *linReg) add(x, y float64) {
-	if l.cnt >= linRegMaxCnt {
-		sub := float64(l.cnt+1-linRegMaxCnt) / linRegMaxCnt
-		l.sumX -= l.sumX * sub
-		l.sumY -= l.sumY * sub
-		l.sumXX -= l.sumXX * sub
-		l.sumXY -= l.sumXY * sub
-		l.cnt = linRegMaxCnt - 1
-	}
-	l.cnt++
-	l.sumX += x
-	l.sumY += y
-	l.sumXX += x * x
-	l.sumXY += x * y
-}
-
-func (l *linReg) calc() (b, m float64) {
-	if l.cnt == 0 {
-		return 0, 0
-	}
-	cnt := float64(l.cnt)
-	d := cnt*l.sumXX - l.sumX*l.sumX
-	if d < 0.001 {
-		return l.sumY / cnt, 0
-	}
-	m = (cnt*l.sumXY - l.sumX*l.sumY) / d
-	b = (l.sumY / cnt) - (m * l.sumX / cnt)
-	return b, m
-}
-
-func (l *linReg) toBytes() []byte {
-	var arr [40]byte
-	binary.BigEndian.PutUint64(arr[0:8], math.Float64bits(l.sumX))
-	binary.BigEndian.PutUint64(arr[8:16], math.Float64bits(l.sumY))
-	binary.BigEndian.PutUint64(arr[16:24], math.Float64bits(l.sumXX))
-	binary.BigEndian.PutUint64(arr[24:32], math.Float64bits(l.sumXY))
-	binary.BigEndian.PutUint64(arr[32:40], l.cnt)
-	return arr[:]
-}
-
-func linRegFromBytes(data []byte) *linReg {
-	if len(data) != 40 {
-		return nil
-	}
-	l := &linReg{}
-	l.sumX = math.Float64frombits(binary.BigEndian.Uint64(data[0:8]))
-	l.sumY = math.Float64frombits(binary.BigEndian.Uint64(data[8:16]))
-	l.sumXX = math.Float64frombits(binary.BigEndian.Uint64(data[16:24]))
-	l.sumXY = math.Float64frombits(binary.BigEndian.Uint64(data[24:32]))
-	l.cnt = binary.BigEndian.Uint64(data[32:40])
-	return l
-}
-
-type requestCostStats struct {
-	lock  sync.RWMutex
-	db    ethdb.Database
-	stats map[uint64]*linReg
-}
-
-type requestCostStatsRlp []struct {
-	MsgCode uint64
-	Data    []byte
-}
-
-var rcStatsKey = []byte("_requestCostStats")
-
-func newCostStats(db ethdb.Database) *requestCostStats {
-	stats := make(map[uint64]*linReg)
-	for _, code := range reqList {
-		stats[code] = &linReg{cnt: 100}
-	}
-
-	if db != nil {
-		data, err := db.Get(rcStatsKey)
-		var statsRlp requestCostStatsRlp
-		if err == nil {
-			err = rlp.DecodeBytes(data, &statsRlp)
-		}
-		if err == nil {
-			for _, r := range statsRlp {
-				if stats[r.MsgCode] != nil {
-					if l := linRegFromBytes(r.Data); l != nil {
-						stats[r.MsgCode] = l
-					}
-				}
-			}
-		}
-	}
-
-	return &requestCostStats{
-		db:    db,
-		stats: stats,
-	}
-}
-
-func (s *requestCostStats) store() {
-	s.lock.Lock()
-	defer s.lock.Unlock()
-
-	statsRlp := make(requestCostStatsRlp, len(reqList))
-	for i, code := range reqList {
-		statsRlp[i].MsgCode = code
-		statsRlp[i].Data = s.stats[code].toBytes()
-	}
-
-	if data, err := rlp.EncodeToBytes(statsRlp); err == nil {
-		s.db.Put(rcStatsKey, data)
-	}
-}
-
-func (s *requestCostStats) getCurrentList() RequestCostList {
-	s.lock.Lock()
-	defer s.lock.Unlock()
-
-	list := make(RequestCostList, len(reqList))
-	for idx, code := range reqList {
-		b, m := s.stats[code].calc()
-		if m < 0 {
-			b += m
-			m = 0
-		}
-		if b < 0 {
-			b = 0
-		}
-
-		list[idx].MsgCode = code
-		list[idx].BaseCost = uint64(b * 2)
-		list[idx].ReqCost = uint64(m * 2)
-	}
-	return list
-}
-
-func (s *requestCostStats) update(msgCode, reqCnt, cost uint64) {
-	s.lock.Lock()
-	defer s.lock.Unlock()
-
-	c, ok := s.stats[msgCode]
-	if !ok || reqCnt == 0 {
-		return
-	}
-	c.add(float64(reqCnt), float64(cost))
-}
-
 func (pm *ProtocolManager) blockLoop() {
 	pm.wg.Add(1)
 	headCh := make(chan core.ChainHeadEvent, 10)
@@ -371,12 +283,7 @@ func (pm *ProtocolManager) blockLoop() {
 							switch p.announceType {
 
 							case announceTypeSimple:
-								select {
-								case p.announceChn <- announce:
-								default:
-									pm.removePeer(p.id)
-								}
-
+								p.queueSend(func() { p.SendAnnounce(announce) })
 							case announceTypeSigned:
 								if !signed {
 									signedAnnounce = announce
@@ -384,11 +291,7 @@ func (pm *ProtocolManager) blockLoop() {
 									signed = true
 								}
 
-								select {
-								case p.announceChn <- signedAnnounce:
-								default:
-									pm.removePeer(p.id)
-								}
+								p.queueSend(func() { p.SendAnnounce(signedAnnounce) })
 							}
 						}
 					}
diff --git a/les/serverpool.go b/les/serverpool.go
index 3f4d0a1d9..668f39c56 100644
--- a/les/serverpool.go
+++ b/les/serverpool.go
@@ -14,7 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package les implements the Light Ethereum Subprotocol.
 package les
 
 import (
diff --git a/les/servingqueue.go b/les/servingqueue.go
new file mode 100644
index 000000000..2438fdfe3
--- /dev/null
+++ b/les/servingqueue.go
@@ -0,0 +1,261 @@
+// Copyright 2018 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"sync"
+
+	"github.com/ethereum/go-ethereum/common/mclock"
+	"github.com/ethereum/go-ethereum/common/prque"
+)
+
+// servingQueue allows running tasks in a limited number of threads and puts the
+// waiting tasks in a priority queue
+type servingQueue struct {
+	tokenCh                 chan runToken
+	queueAddCh, queueBestCh chan *servingTask
+	stopThreadCh, quit      chan struct{}
+	setThreadsCh            chan int
+
+	wg          sync.WaitGroup
+	threadCount int          // number of currently running threads
+	queue       *prque.Prque // priority queue for waiting or suspended tasks
+	best        *servingTask // the highest priority task (not included in the queue)
+	suspendBias int64        // priority bias against suspending an already running task
+}
+
+// servingTask represents a request serving task. Tasks can be implemented to
+// run in multiple steps, allowing the serving queue to suspend execution between
+// steps if higher priority tasks are entered. The creator of the task should
+// set the following fields:
+//
+// - priority: greater value means higher priority; values can wrap around the int64 range
+// - run: execute a single step; return true if finished
+// - after: executed after run finishes or returns an error, receives the total serving time
+type servingTask struct {
+	sq          *servingQueue
+	servingTime uint64
+	priority    int64
+	biasAdded   bool
+	token       runToken
+	tokenCh     chan runToken
+}
+
+// runToken received by servingTask.start allows the task to run. Closing the
+// channel by servingTask.stop signals the thread controller to allow a new task
+// to start running.
+type runToken chan struct{}
+
+// start blocks until the task can start and returns true if it is allowed to run.
+// Returning false means that the task should be cancelled.
+func (t *servingTask) start() bool {
+	select {
+	case t.token = <-t.sq.tokenCh:
+	default:
+		t.tokenCh = make(chan runToken, 1)
+		select {
+		case t.sq.queueAddCh <- t:
+		case <-t.sq.quit:
+			return false
+		}
+		select {
+		case t.token = <-t.tokenCh:
+		case <-t.sq.quit:
+			return false
+		}
+	}
+	if t.token == nil {
+		return false
+	}
+	t.servingTime -= uint64(mclock.Now())
+	return true
+}
+
+// done signals the thread controller about the task being finished and returns
+// the total serving time of the task in nanoseconds.
+func (t *servingTask) done() uint64 {
+	t.servingTime += uint64(mclock.Now())
+	close(t.token)
+	return t.servingTime
+}
+
+// waitOrStop can be called during the execution of the task. It blocks if there
+// is a higher priority task waiting (a bias is applied in favor of the currently
+// running task). Returning true means that the execution can be resumed. False
+// means the task should be cancelled.
+func (t *servingTask) waitOrStop() bool {
+	t.done()
+	if !t.biasAdded {
+		t.priority += t.sq.suspendBias
+		t.biasAdded = true
+	}
+	return t.start()
+}
+
+// newServingQueue returns a new servingQueue
+func newServingQueue(suspendBias int64) *servingQueue {
+	sq := &servingQueue{
+		queue:        prque.New(nil),
+		suspendBias:  suspendBias,
+		tokenCh:      make(chan runToken),
+		queueAddCh:   make(chan *servingTask, 100),
+		queueBestCh:  make(chan *servingTask),
+		stopThreadCh: make(chan struct{}),
+		quit:         make(chan struct{}),
+		setThreadsCh: make(chan int, 10),
+	}
+	sq.wg.Add(2)
+	go sq.queueLoop()
+	go sq.threadCountLoop()
+	return sq
+}
+
+// newTask creates a new task with the given priority
+func (sq *servingQueue) newTask(priority int64) *servingTask {
+	return &servingTask{
+		sq:       sq,
+		priority: priority,
+	}
+}
+
+// threadController is started in multiple goroutines and controls the execution
+// of tasks. The number of active thread controllers equals the allowed number of
+// concurrently running threads. It tries to fetch the highest priority queued
+// task first. If there are no queued tasks waiting then it can directly catch
+// run tokens from the token channel and allow the corresponding tasks to run
+// without entering the priority queue.
+func (sq *servingQueue) threadController() {
+	for {
+		token := make(runToken)
+		select {
+		case best := <-sq.queueBestCh:
+			best.tokenCh <- token
+		default:
+			select {
+			case best := <-sq.queueBestCh:
+				best.tokenCh <- token
+			case sq.tokenCh <- token:
+			case <-sq.stopThreadCh:
+				sq.wg.Done()
+				return
+			case <-sq.quit:
+				sq.wg.Done()
+				return
+			}
+		}
+		<-token
+		select {
+		case <-sq.stopThreadCh:
+			sq.wg.Done()
+			return
+		case <-sq.quit:
+			sq.wg.Done()
+			return
+		default:
+		}
+	}
+}
+
+// addTask inserts a task into the priority queue
+func (sq *servingQueue) addTask(task *servingTask) {
+	if sq.best == nil {
+		sq.best = task
+	} else if task.priority > sq.best.priority {
+		sq.queue.Push(sq.best, sq.best.priority)
+		sq.best = task
+		return
+	} else {
+		sq.queue.Push(task, task.priority)
+	}
+}
+
+// queueLoop is an event loop running in a goroutine. It receives tasks from queueAddCh
+// and always tries to send the highest priority task to queueBestCh. Successfully sent
+// tasks are removed from the queue.
+func (sq *servingQueue) queueLoop() {
+	for {
+		if sq.best != nil {
+			select {
+			case task := <-sq.queueAddCh:
+				sq.addTask(task)
+			case sq.queueBestCh <- sq.best:
+				if sq.queue.Size() == 0 {
+					sq.best = nil
+				} else {
+					sq.best, _ = sq.queue.PopItem().(*servingTask)
+				}
+			case <-sq.quit:
+				sq.wg.Done()
+				return
+			}
+		} else {
+			select {
+			case task := <-sq.queueAddCh:
+				sq.addTask(task)
+			case <-sq.quit:
+				sq.wg.Done()
+				return
+			}
+		}
+	}
+}
+
+// threadCountLoop is an event loop running in a goroutine. It adjusts the number
+// of active thread controller goroutines.
+func (sq *servingQueue) threadCountLoop() {
+	var threadCountTarget int
+	for {
+		for threadCountTarget > sq.threadCount {
+			sq.wg.Add(1)
+			go sq.threadController()
+			sq.threadCount++
+		}
+		if threadCountTarget < sq.threadCount {
+			select {
+			case threadCountTarget = <-sq.setThreadsCh:
+			case sq.stopThreadCh <- struct{}{}:
+				sq.threadCount--
+			case <-sq.quit:
+				sq.wg.Done()
+				return
+			}
+		} else {
+			select {
+			case threadCountTarget = <-sq.setThreadsCh:
+			case <-sq.quit:
+				sq.wg.Done()
+				return
+			}
+		}
+	}
+}
+
+// setThreads sets the allowed processing thread count, suspending tasks as soon as
+// possible if necessary.
+func (sq *servingQueue) setThreads(threadCount int) {
+	select {
+	case sq.setThreadsCh <- threadCount:
+	case <-sq.quit:
+		return
+	}
+}
+
+// stop stops task processing as soon as possible and shuts down the serving queue.
+func (sq *servingQueue) stop() {
+	close(sq.quit)
+	sq.wg.Wait()
+}
diff --git a/les/txrelay.go b/les/txrelay.go
index 6d22856f9..a790bbec9 100644
--- a/les/txrelay.go
+++ b/les/txrelay.go
@@ -21,6 +21,7 @@ import (
 
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core/types"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 type ltrInfo struct {
@@ -113,21 +114,22 @@ func (self *LesTxRelay) send(txs types.Transactions, count int) {
 	for p, list := range sendTo {
 		pp := p
 		ll := list
+		enc, _ := rlp.EncodeToBytes(ll)
 
 		reqID := genReqID()
 		rq := &distReq{
 			getCost: func(dp distPeer) uint64 {
 				peer := dp.(*peer)
-				return peer.GetRequestCost(SendTxMsg, len(ll))
+				return peer.GetTxRelayCost(len(ll), len(enc))
 			},
 			canSend: func(dp distPeer) bool {
 				return !dp.(*peer).isOnlyAnnounce && dp.(*peer) == pp
 			},
 			request: func(dp distPeer) func() {
 				peer := dp.(*peer)
-				cost := peer.GetRequestCost(SendTxMsg, len(ll))
-				peer.fcServer.QueueRequest(reqID, cost)
-				return func() { peer.SendTxs(reqID, cost, ll) }
+				cost := peer.GetTxRelayCost(len(ll), len(enc))
+				peer.fcServer.QueuedRequest(reqID, cost)
+				return func() { peer.SendTxs(reqID, cost, enc) }
 			},
 		}
 		self.reqDist.queue(rq)
diff --git a/les/ulc_test.go b/les/ulc_test.go
index 3b95e6368..69ea62059 100644
--- a/les/ulc_test.go
+++ b/les/ulc_test.go
@@ -11,6 +11,7 @@ import (
 	"crypto/ecdsa"
 	"math/big"
 
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/eth"
@@ -217,7 +218,7 @@ func newFullPeerPair(t *testing.T, index int, numberOfblocks int, chainGen func(
 // newLightPeer creates node with light sync mode
 func newLightPeer(t *testing.T, ulcConfig *eth.ULCConfig) pairPeer {
 	peers := newPeerSet()
-	dist := newRequestDistributor(peers, make(chan struct{}))
+	dist := newRequestDistributor(peers, make(chan struct{}), &mclock.System{})
 	rm := newRetrieveManager(peers, dist, nil)
 	ldb := ethdb.NewMemDatabase()
 
diff --git a/light/lightchain.go b/light/lightchain.go
index 5019622c7..fb5f8ead2 100644
--- a/light/lightchain.go
+++ b/light/lightchain.go
@@ -14,6 +14,8 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
+// Package light implements on-demand retrieval capable state and chain objects
+// for the Ethereum Light Client.
 package light
 
 import (
diff --git a/light/odr.go b/light/odr.go
index 900be0544..95f1948e7 100644
--- a/light/odr.go
+++ b/light/odr.go
@@ -14,8 +14,6 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
-// Package light implements on-demand retrieval capable state and chain objects
-// for the Ethereum Light Client.
 package light
 
 import (
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 9b588db1b..bd8bcbc85 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -97,7 +97,11 @@ func (e *ExecAdapter) NewNode(config *NodeConfig) (Node, error) {
 		Stack: node.DefaultConfig,
 		Node:  config,
 	}
-	conf.Stack.DataDir = filepath.Join(dir, "data")
+	if config.DataDir != "" {
+		conf.Stack.DataDir = config.DataDir
+	} else {
+		conf.Stack.DataDir = filepath.Join(dir, "data")
+	}
 	conf.Stack.WSHost = "127.0.0.1"
 	conf.Stack.WSPort = 0
 	conf.Stack.WSOrigins = []string{"*"}
diff --git a/p2p/simulations/adapters/types.go b/p2p/simulations/adapters/types.go
index 6681726e4..31856b76d 100644
--- a/p2p/simulations/adapters/types.go
+++ b/p2p/simulations/adapters/types.go
@@ -90,6 +90,9 @@ type NodeConfig struct {
 	// Name is a human friendly name for the node like "node01"
 	Name string
 
+	// Use an existing database instead of a temporary one if non-empty
+	DataDir string
+
 	// Services are the names of the services which should be run when
 	// starting the node (for SimNodes it should be the names of services
 	// contained in SimAdapter.services, for other nodes it should be
