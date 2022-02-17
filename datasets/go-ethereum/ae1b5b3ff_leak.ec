commit ae1b5b3ff2611af1232643d38e13a77d704dae28
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Oct 26 21:42:24 2015 +0100

    eth, xeth: fix GasPriceOracle goroutine leak
    
    XEth.gpo was being initialized as needed. WithState copies the XEth
    struct including the gpo field. If gpo was nil at the time of the copy
    and Call or Transact were invoked on it, an additional GPO listenLoop
    would be spawned.
    
    Move the lazy initialization to GasPriceOracle instead so the same GPO
    instance is shared among all created XEths.
    
    Fixes #1317
    Might help with #1930

diff --git a/eth/gasprice.go b/eth/gasprice.go
index b4409f346..b752c22dd 100644
--- a/eth/gasprice.go
+++ b/eth/gasprice.go
@@ -23,49 +23,66 @@ import (
 
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 )
 
-const gpoProcessPastBlocks = 100
+const (
+	gpoProcessPastBlocks = 100
+
+	// for testing
+	gpoDefaultBaseCorrectionFactor = 110
+	gpoDefaultMinGasPrice          = 10000000000000
+)
 
 type blockPriceInfo struct {
 	baseGasPrice *big.Int
 }
 
+// GasPriceOracle recommends gas prices based on the content of recent
+// blocks.
 type GasPriceOracle struct {
-	eth                           *Ethereum
-	chain                         *core.BlockChain
-	events                        event.Subscription
+	eth           *Ethereum
+	initOnce      sync.Once
+	minPrice      *big.Int
+	lastBaseMutex sync.Mutex
+	lastBase      *big.Int
+
+	// state of listenLoop
 	blocks                        map[uint64]*blockPriceInfo
 	firstProcessed, lastProcessed uint64
-	lastBaseMutex                 sync.Mutex
-	lastBase, minBase             *big.Int
+	minBase                       *big.Int
+}
+
+// NewGasPriceOracle returns a new oracle.
+func NewGasPriceOracle(eth *Ethereum) *GasPriceOracle {
+	minprice := eth.GpoMinGasPrice
+	if minprice == nil {
+		minprice = big.NewInt(gpoDefaultMinGasPrice)
+	}
+	minbase := new(big.Int).Mul(minprice, big.NewInt(100))
+	if eth.GpobaseCorrectionFactor > 0 {
+		minbase = minbase.Div(minbase, big.NewInt(int64(eth.GpobaseCorrectionFactor)))
+	}
+	return &GasPriceOracle{
+		eth:      eth,
+		blocks:   make(map[uint64]*blockPriceInfo),
+		minBase:  minbase,
+		minPrice: minprice,
+		lastBase: minprice,
+	}
 }
 
-func NewGasPriceOracle(eth *Ethereum) (self *GasPriceOracle) {
-	self = &GasPriceOracle{}
-	self.blocks = make(map[uint64]*blockPriceInfo)
-	self.eth = eth
-	self.chain = eth.blockchain
-	self.events = eth.EventMux().Subscribe(
-		core.ChainEvent{},
-		core.ChainSplitEvent{},
-	)
-
-	minbase := new(big.Int).Mul(self.eth.GpoMinGasPrice, big.NewInt(100))
-	minbase = minbase.Div(minbase, big.NewInt(int64(self.eth.GpobaseCorrectionFactor)))
-	self.minBase = minbase
-
-	self.processPastBlocks()
-	go self.listenLoop()
-	return
+func (gpo *GasPriceOracle) init() {
+	gpo.initOnce.Do(func() {
+		gpo.processPastBlocks(gpo.eth.BlockChain())
+		go gpo.listenLoop()
+	})
 }
 
-func (self *GasPriceOracle) processPastBlocks() {
+func (self *GasPriceOracle) processPastBlocks(chain *core.BlockChain) {
 	last := int64(-1)
-	cblock := self.chain.CurrentBlock()
+	cblock := chain.CurrentBlock()
 	if cblock != nil {
 		last = int64(cblock.NumberU64())
 	}
@@ -75,7 +92,7 @@ func (self *GasPriceOracle) processPastBlocks() {
 	}
 	self.firstProcessed = uint64(first)
 	for i := first; i <= last; i++ {
-		block := self.chain.GetBlockByNumber(uint64(i))
+		block := chain.GetBlockByNumber(uint64(i))
 		if block != nil {
 			self.processBlock(block)
 		}
@@ -84,9 +101,10 @@ func (self *GasPriceOracle) processPastBlocks() {
 }
 
 func (self *GasPriceOracle) listenLoop() {
-	defer self.events.Unsubscribe()
+	events := self.eth.EventMux().Subscribe(core.ChainEvent{}, core.ChainSplitEvent{})
+	defer events.Unsubscribe()
 
-	for event := range self.events.Chan() {
+	for event := range events.Chan() {
 		switch event := event.Data.(type) {
 		case core.ChainEvent:
 			self.processBlock(event.Block)
@@ -102,7 +120,7 @@ func (self *GasPriceOracle) processBlock(block *types.Block) {
 		self.lastProcessed = i
 	}
 
-	lastBase := self.eth.GpoMinGasPrice
+	lastBase := self.minPrice
 	bpl := self.blocks[i-1]
 	if bpl != nil {
 		lastBase = bpl.baseGasPrice
@@ -176,28 +194,19 @@ func (self *GasPriceOracle) lowestPrice(block *types.Block) *big.Int {
 	return minPrice
 }
 
+// SuggestPrice returns the recommended gas price.
 func (self *GasPriceOracle) SuggestPrice() *big.Int {
+	self.init()
 	self.lastBaseMutex.Lock()
-	base := self.lastBase
+	price := new(big.Int).Set(self.lastBase)
 	self.lastBaseMutex.Unlock()
 
-	if base == nil {
-		base = self.eth.GpoMinGasPrice
+	price.Mul(price, big.NewInt(int64(self.eth.GpobaseCorrectionFactor)))
+	price.Div(price, big.NewInt(100))
+	if price.Cmp(self.minPrice) < 0 {
+		price.Set(self.minPrice)
+	} else if self.eth.GpoMaxGasPrice != nil && price.Cmp(self.eth.GpoMaxGasPrice) > 0 {
+		price.Set(self.eth.GpoMaxGasPrice)
 	}
-	if base == nil {
-		return big.NewInt(10000000000000) // apparently MinGasPrice is not initialized during some tests
-	}
-
-	baseCorr := new(big.Int).Mul(base, big.NewInt(int64(self.eth.GpobaseCorrectionFactor)))
-	baseCorr.Div(baseCorr, big.NewInt(100))
-
-	if baseCorr.Cmp(self.eth.GpoMinGasPrice) < 0 {
-		return self.eth.GpoMinGasPrice
-	}
-
-	if baseCorr.Cmp(self.eth.GpoMaxGasPrice) > 0 {
-		return self.eth.GpoMaxGasPrice
-	}
-
-	return baseCorr
+	return price
 }
diff --git a/xeth/xeth.go b/xeth/xeth.go
index 1cb072f0d..f1e8cc5ee 100644
--- a/xeth/xeth.go
+++ b/xeth/xeth.go
@@ -59,24 +59,8 @@ const (
 	LogFilterTy
 )
 
-func DefaultGas() *big.Int { return new(big.Int).Set(defaultGas) }
-
-func (self *XEth) DefaultGasPrice() *big.Int {
-	if self.gpo == nil {
-		self.gpo = eth.NewGasPriceOracle(self.backend)
-	}
-	return self.gpo.SuggestPrice()
-}
-
 type XEth struct {
-	backend  *eth.Ethereum
-	frontend Frontend
-
-	state   *State
-	whisper *Whisper
-
-	quit          chan struct{}
-	filterManager *filters.FilterSystem
+	quit chan struct{}
 
 	logMu    sync.RWMutex
 	logQueue map[int]*logQueue
@@ -92,16 +76,18 @@ type XEth struct {
 
 	transactMu sync.Mutex
 
-	agent *miner.RemoteAgent
-
-	gpo *eth.GasPriceOracle
+	// read-only fields
+	backend       *eth.Ethereum
+	frontend      Frontend
+	agent         *miner.RemoteAgent
+	gpo           *eth.GasPriceOracle
+	state         *State
+	whisper       *Whisper
+	filterManager *filters.FilterSystem
 }
 
 func NewTest(eth *eth.Ethereum, frontend Frontend) *XEth {
-	return &XEth{
-		backend:  eth,
-		frontend: frontend,
-	}
+	return &XEth{backend: eth, frontend: frontend}
 }
 
 // New creates an XEth that uses the given frontend.
@@ -118,6 +104,7 @@ func New(ethereum *eth.Ethereum, frontend Frontend) *XEth {
 		transactionQueue: make(map[int]*hashQueue),
 		messages:         make(map[int]*whisperFilter),
 		agent:            miner.NewRemoteAgent(),
+		gpo:              eth.NewGasPriceOracle(ethereum),
 	}
 	if ethereum.Whisper() != nil {
 		xeth.whisper = NewWhisper(ethereum.Whisper())
@@ -207,6 +194,12 @@ func cTopics(t [][]string) [][]common.Hash {
 	return topics
 }
 
+func DefaultGas() *big.Int { return new(big.Int).Set(defaultGas) }
+
+func (self *XEth) DefaultGasPrice() *big.Int {
+	return self.gpo.SuggestPrice()
+}
+
 func (self *XEth) RemoteMining() *miner.RemoteAgent { return self.agent }
 
 func (self *XEth) AtStateNum(num int64) *XEth {
