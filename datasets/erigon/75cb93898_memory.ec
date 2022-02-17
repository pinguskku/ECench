commit 75cb93898009234259811e22fb96eca5a8798ebd
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Sun Jan 3 02:28:22 2021 +0700

    rpcdaemon performance improve - less reading blocks, less allocs on server (#1426)
    
    * rpcdaemon performance improve - less reading blocks, less allocs on server
    
    * rpcdaemon performance improve - less reading blocks, less allocs on server
    
    * rpcdaemon performance improve - less reading blocks, less allocs on server
    
    * rpcdaemon performance improve - less reading blocks, less allocs on server
    
    * don't use global variables
    
    * df
    
    * avoid use non-transactional db instance to reduce amount of cursors

diff --git a/cmd/rpcdaemon/commands/debug_api.go b/cmd/rpcdaemon/commands/debug_api.go
index ac74459ac..5df09a222 100644
--- a/cmd/rpcdaemon/commands/debug_api.go
+++ b/cmd/rpcdaemon/commands/debug_api.go
@@ -29,6 +29,7 @@ type PrivateDebugAPI interface {
 
 // PrivateDebugAPIImpl is implementation of the PrivateDebugAPI interface based on remote Db access
 type PrivateDebugAPIImpl struct {
+	*BaseAPI
 	dbReader     ethdb.Database
 	chainContext core.ChainContext
 }
@@ -36,6 +37,7 @@ type PrivateDebugAPIImpl struct {
 // NewPrivateDebugAPI returns PrivateDebugAPIImpl instance
 func NewPrivateDebugAPI(dbReader ethdb.Database) *PrivateDebugAPIImpl {
 	return &PrivateDebugAPIImpl{
+		BaseAPI:  &BaseAPI{},
 		dbReader: dbReader,
 	}
 }
diff --git a/cmd/rpcdaemon/commands/eth_accounts.go b/cmd/rpcdaemon/commands/eth_accounts.go
index 4e1a1f26d..5a9d533f1 100644
--- a/cmd/rpcdaemon/commands/eth_accounts.go
+++ b/cmd/rpcdaemon/commands/eth_accounts.go
@@ -16,16 +16,16 @@ import (
 
 // GetBalance implements eth_getBalance. Returns the balance of an account for a given address.
 func (api *APIImpl) GetBalance(ctx context.Context, address common.Address, blockNrOrHash rpc.BlockNumberOrHash) (*hexutil.Big, error) {
-	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, api.dbReader)
-	if err != nil {
-		return nil, err
-	}
-
-	tx, err1 := api.db.Begin(ctx, nil, ethdb.RO)
+	tx, err1 := api.dbReader.Begin(ctx, ethdb.RO)
 	if err1 != nil {
 		return nil, fmt.Errorf("getBalance cannot open tx: %v", err1)
 	}
 	defer tx.Rollback()
+	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, tx)
+	if err != nil {
+		return nil, err
+	}
+
 	acc, err := rpchelper.GetAccount(tx, blockNumber, address)
 	if err != nil {
 		return nil, fmt.Errorf("cant get a balance for account %q for block %v", address.String(), blockNumber)
@@ -40,17 +40,17 @@ func (api *APIImpl) GetBalance(ctx context.Context, address common.Address, bloc
 
 // GetTransactionCount implements eth_getTransactionCount. Returns the number of transactions sent from an address (the nonce).
 func (api *APIImpl) GetTransactionCount(ctx context.Context, address common.Address, blockNrOrHash rpc.BlockNumberOrHash) (*hexutil.Uint64, error) {
-	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, api.dbReader)
-	if err != nil {
-		return nil, err
-	}
-	nonce := hexutil.Uint64(0)
-	tx, err1 := api.db.Begin(ctx, nil, ethdb.RO)
+	tx, err1 := api.dbReader.Begin(ctx, ethdb.RO)
 	if err1 != nil {
 		return nil, fmt.Errorf("getTransactionCount cannot open tx: %v", err1)
 	}
 	defer tx.Rollback()
-	reader := adapter.NewStateReader(tx, blockNumber)
+	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, tx)
+	if err != nil {
+		return nil, err
+	}
+	nonce := hexutil.Uint64(0)
+	reader := adapter.NewStateReader(tx.(ethdb.HasTx).Tx(), blockNumber)
 	acc, err := reader.ReadAccountData(address)
 	if acc == nil || err != nil {
 		return &nonce, err
@@ -60,17 +60,17 @@ func (api *APIImpl) GetTransactionCount(ctx context.Context, address common.Addr
 
 // GetCode implements eth_getCode. Returns the byte code at a given address (if it's a smart contract).
 func (api *APIImpl) GetCode(ctx context.Context, address common.Address, blockNrOrHash rpc.BlockNumberOrHash) (hexutil.Bytes, error) {
-	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, api.dbReader)
-	if err != nil {
-		return nil, err
-	}
-
-	tx, err1 := api.db.Begin(ctx, nil, ethdb.RO)
+	tx, err1 := api.dbReader.Begin(ctx, ethdb.RO)
 	if err1 != nil {
 		return nil, fmt.Errorf("getCode cannot open tx: %v", err1)
 	}
 	defer tx.Rollback()
-	reader := adapter.NewStateReader(tx, blockNumber)
+	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, tx)
+	if err != nil {
+		return nil, err
+	}
+
+	reader := adapter.NewStateReader(tx.(ethdb.HasTx).Tx(), blockNumber)
 	acc, err := reader.ReadAccountData(address)
 	if acc == nil || err != nil {
 		return hexutil.Bytes(""), nil
@@ -86,17 +86,17 @@ func (api *APIImpl) GetCode(ctx context.Context, address common.Address, blockNr
 func (api *APIImpl) GetStorageAt(ctx context.Context, address common.Address, index string, blockNrOrHash rpc.BlockNumberOrHash) (string, error) {
 	var empty []byte
 
-	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, api.dbReader)
-	if err != nil {
-		return hexutil.Encode(common.LeftPadBytes(empty[:], 32)), err
-	}
-
-	tx, err1 := api.db.Begin(ctx, nil, ethdb.RO)
+	tx, err1 := api.dbReader.Begin(ctx, ethdb.RO)
 	if err1 != nil {
-		return "", fmt.Errorf("getStorageAt cannot open tx: %v", err1)
+		return hexutil.Encode(common.LeftPadBytes(empty[:], 32)), err1
 	}
 	defer tx.Rollback()
-	reader := adapter.NewStateReader(tx, blockNumber)
+
+	blockNumber, _, err := rpchelper.GetBlockNumber(blockNrOrHash, tx)
+	if err != nil {
+		return hexutil.Encode(common.LeftPadBytes(empty[:], 32)), err
+	}
+	reader := adapter.NewStateReader(tx.(ethdb.HasTx).Tx(), blockNumber)
 	acc, err := reader.ReadAccountData(address)
 	if acc == nil || err != nil {
 		return hexutil.Encode(common.LeftPadBytes(empty[:], 32)), err
diff --git a/cmd/rpcdaemon/commands/eth_api.go b/cmd/rpcdaemon/commands/eth_api.go
index f45a79992..3ab054511 100644
--- a/cmd/rpcdaemon/commands/eth_api.go
+++ b/cmd/rpcdaemon/commands/eth_api.go
@@ -3,15 +3,18 @@ package commands
 import (
 	"context"
 	"math/big"
+	"sync"
 
 	rpcfilters "github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/filters"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core"
+	"github.com/ledgerwatch/turbo-geth/core/rawdb"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/eth/filters"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/internal/ethapi"
+	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rpc"
 )
 
@@ -83,8 +86,48 @@ type EthAPI interface {
 	CompileSerpent(ctx context.Context, _ string) (hexutil.Bytes, error)
 }
 
+type BaseAPI struct {
+	_chainConfig    *params.ChainConfig
+	_genesis        *types.Block
+	_genesisSetOnce sync.Once
+}
+
+func (api *BaseAPI) chainConfig(db ethdb.Database) (*params.ChainConfig, error) {
+	cfg, _, err := api.chainConfigWithGenesis(db)
+	return cfg, err
+}
+
+//nolint:unused
+func (api *BaseAPI) genesis(db ethdb.Database) (*types.Block, error) {
+	_, genesis, err := api.chainConfigWithGenesis(db)
+	return genesis, err
+}
+
+func (api *BaseAPI) chainConfigWithGenesis(db ethdb.Database) (*params.ChainConfig, *types.Block, error) {
+	if api._chainConfig != nil {
+		return api._chainConfig, api._genesis, nil
+	}
+
+	genesisBlock, err := rawdb.ReadBlockByNumber(db, 0)
+	if err != nil {
+		return nil, nil, err
+	}
+	cc, err := rawdb.ReadChainConfig(db, genesisBlock.Hash())
+	if err != nil {
+		return nil, nil, err
+	}
+	if cc != nil && genesisBlock != nil {
+		api._genesisSetOnce.Do(func() {
+			api._genesis = genesisBlock
+			api._chainConfig = cc
+		})
+	}
+	return cc, genesisBlock, nil
+}
+
 // APIImpl is implementation of the EthAPI interface based on remote Db access
 type APIImpl struct {
+	*BaseAPI
 	db           ethdb.KV
 	ethBackend   ethdb.Backend
 	dbReader     ethdb.Database
@@ -96,6 +139,7 @@ type APIImpl struct {
 // NewEthAPI returns APIImpl instance
 func NewEthAPI(db ethdb.KV, dbReader ethdb.Database, eth ethdb.Backend, gascap uint64, filters *rpcfilters.Filters) *APIImpl {
 	return &APIImpl{
+		BaseAPI:    &BaseAPI{},
 		db:         db,
 		dbReader:   dbReader,
 		ethBackend: eth,
diff --git a/cmd/rpcdaemon/commands/eth_call.go b/cmd/rpcdaemon/commands/eth_call.go
index 83d6289eb..b85b50eab 100644
--- a/cmd/rpcdaemon/commands/eth_call.go
+++ b/cmd/rpcdaemon/commands/eth_call.go
@@ -29,12 +29,12 @@ func (api *APIImpl) Call(ctx context.Context, args ethapi.CallArgs, blockNrOrHas
 	}
 	defer dbtx.Rollback()
 
-	chainConfig, err := getChainConfig(dbtx)
+	chainConfig, err := api.chainConfig(dbtx)
 	if err != nil {
 		return nil, err
 	}
 
-	result, err := transactions.DoCall(ctx, args, dbtx, api.dbReader, blockNrOrHash, overrides, api.GasCap, chainConfig)
+	result, err := transactions.DoCall(ctx, args, dbtx, blockNrOrHash, overrides, api.GasCap, chainConfig)
 	if err != nil {
 		return nil, err
 	}
@@ -73,12 +73,12 @@ func (api *APIImpl) DoEstimateGas(ctx context.Context, args ethapi.CallArgs, blo
 		args.From = new(common.Address)
 	}
 
-	blockNumber, hash, err := rpchelper.GetBlockNumber(blockNrOrHash, api.dbReader)
+	blockNumber, hash, err := rpchelper.GetBlockNumber(blockNrOrHash, dbtx)
 	if err != nil {
 		return 0, err
 	}
 
-	chainConfig, err := getChainConfig(dbtx)
+	chainConfig, err := api.chainConfig(dbtx)
 	if err != nil {
 		return 0, err
 	}
@@ -88,7 +88,7 @@ func (api *APIImpl) DoEstimateGas(ctx context.Context, args ethapi.CallArgs, blo
 		hi = uint64(*args.Gas)
 	} else {
 		// Retrieve the block to act as the gas ceiling
-		header := rawdb.ReadHeader(api.dbReader, hash, blockNumber)
+		header := rawdb.ReadHeader(dbtx, hash, blockNumber)
 		hi = header.GasLimit
 	}
 	// Recap the highest gas limit with account's available balance.
@@ -129,7 +129,7 @@ func (api *APIImpl) DoEstimateGas(ctx context.Context, args ethapi.CallArgs, blo
 	executable := func(gas uint64) (bool, *core.ExecutionResult, error) {
 		args.Gas = (*hexutil.Uint64)(&gas)
 
-		result, err := transactions.DoCall(ctx, args, dbtx, api.dbReader, blockNrOrHash, nil, api.GasCap, chainConfig)
+		result, err := transactions.DoCall(ctx, args, dbtx, blockNrOrHash, nil, api.GasCap, chainConfig)
 		if err != nil {
 			if errors.Is(err, core.ErrIntrinsicGas) {
 				// Special case, raise gas limit
diff --git a/cmd/rpcdaemon/commands/eth_receipts.go b/cmd/rpcdaemon/commands/eth_receipts.go
index 7fe0f4037..1cf7e3131 100644
--- a/cmd/rpcdaemon/commands/eth_receipts.go
+++ b/cmd/rpcdaemon/commands/eth_receipts.go
@@ -16,11 +16,12 @@ import (
 	"github.com/ledgerwatch/turbo-geth/eth/filters"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/ethdb/bitmapdb"
+	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/turbo/adapter"
 	"github.com/ledgerwatch/turbo-geth/turbo/transactions"
 )
 
-func getReceipts(ctx context.Context, tx ethdb.Database, number uint64, hash common.Hash) (types.Receipts, error) {
+func getReceipts(ctx context.Context, tx ethdb.Database, chainConfig *params.ChainConfig, number uint64, hash common.Hash) (types.Receipts, error) {
 	if cached := rawdb.ReadReceipts(tx, hash, number); cached != nil {
 		return cached, nil
 	}
@@ -29,10 +30,6 @@ func getReceipts(ctx context.Context, tx ethdb.Database, number uint64, hash com
 
 	cc := adapter.NewChainContext(tx)
 	bc := adapter.NewBlockGetter(tx)
-	chainConfig, err := getChainConfig(tx)
-	if err != nil {
-		return nil, err
-	}
 	_, _, ibs, dbstate, err := transactions.ComputeTxEnv(ctx, bc, chainConfig, cc, tx.(ethdb.HasTx).Tx(), hash, 0)
 	if err != nil {
 		return nil, err
@@ -67,7 +64,7 @@ func (api *APIImpl) GetLogs(ctx context.Context, crit filters.FilterCriteria) ([
 	defer tx.Rollback()
 
 	if crit.BlockHash != nil {
-		number := rawdb.ReadHeaderNumber(api.dbReader, *crit.BlockHash)
+		number := rawdb.ReadHeaderNumber(tx, *crit.BlockHash)
 		if number == nil {
 			return nil, fmt.Errorf("block not found: %x", *crit.BlockHash)
 		}
@@ -75,7 +72,7 @@ func (api *APIImpl) GetLogs(ctx context.Context, crit filters.FilterCriteria) ([
 		end = *number
 	} else {
 		// Convert the RPC block numbers into internal representations
-		latest, err := getLatestBlockNumber(api.dbReader)
+		latest, err := getLatestBlockNumber(tx)
 		if err != nil {
 			return nil, err
 		}
@@ -130,6 +127,10 @@ func (api *APIImpl) GetLogs(ctx context.Context, crit filters.FilterCriteria) ([
 		return returnLogs(logs), nil
 	}
 
+	cc, err := api.chainConfig(tx)
+	if err != nil {
+		return returnLogs(logs), err
+	}
 	for _, blockNToMatch := range blockNumbers.ToArray() {
 		blockHash, err := rawdb.ReadCanonicalHash(tx, uint64(blockNToMatch))
 		if err != nil {
@@ -138,7 +139,7 @@ func (api *APIImpl) GetLogs(ctx context.Context, crit filters.FilterCriteria) ([
 		if blockHash == (common.Hash{}) {
 			return returnLogs(logs), fmt.Errorf("block not found %d", uint64(blockNToMatch))
 		}
-		receipts, err := getReceipts(ctx, tx, uint64(blockNToMatch), blockHash)
+		receipts, err := getReceipts(ctx, tx, cc, uint64(blockNToMatch), blockHash)
 		if err != nil {
 			return returnLogs(logs), err
 		}
@@ -205,7 +206,11 @@ func (api *APIImpl) GetTransactionReceipt(ctx context.Context, hash common.Hash)
 		return nil, fmt.Errorf("transaction %#x not found", hash)
 	}
 
-	receipts, err := getReceipts(ctx, tx, blockNumber, blockHash)
+	cc, err := api.chainConfig(tx)
+	if err != nil {
+		return nil, err
+	}
+	receipts, err := getReceipts(ctx, tx, cc, blockNumber, blockHash)
 	if err != nil {
 		return nil, fmt.Errorf("getReceipts error: %v", err)
 	}
diff --git a/cmd/rpcdaemon/commands/eth_system.go b/cmd/rpcdaemon/commands/eth_system.go
index e2fa36579..75c71cc88 100644
--- a/cmd/rpcdaemon/commands/eth_system.go
+++ b/cmd/rpcdaemon/commands/eth_system.go
@@ -26,13 +26,18 @@ func (api *APIImpl) BlockNumber(_ context.Context) (hexutil.Uint64, error) {
 }
 
 // Syncing implements eth_syncing. Returns a data object detaling the status of the sync process or false if not syncing.
-func (api *APIImpl) Syncing(_ context.Context) (interface{}, error) {
-	highestBlock, err := stages.GetStageProgress(api.dbReader, stages.Headers)
+func (api *APIImpl) Syncing(ctx context.Context) (interface{}, error) {
+	tx, err := api.dbReader.Begin(ctx, ethdb.RO)
+	if err != nil {
+		return nil, err
+	}
+	defer tx.Rollback()
+	highestBlock, err := stages.GetStageProgress(tx, stages.Headers)
 	if err != nil {
 		return false, err
 	}
 
-	currentBlock, err := stages.GetStageProgress(api.dbReader, stages.Finish)
+	currentBlock, err := stages.GetStageProgress(tx, stages.Finish)
 	if err != nil {
 		return false, err
 	}
@@ -56,7 +61,7 @@ func (api *APIImpl) ChainId(ctx context.Context) (hexutil.Uint64, error) {
 	}
 	defer tx.Rollback()
 
-	chainConfig, err := getChainConfig(tx)
+	chainConfig, err := api.chainConfig(tx)
 	if err != nil {
 		return 0, err
 	}
@@ -127,7 +132,7 @@ func (api *APIImpl) ChainConfig() *params.ChainConfig {
 	}
 	defer tx.Rollback()
 
-	chainConfig, err := getChainConfig(tx)
+	chainConfig, err := api.chainConfig(tx)
 	if err != nil {
 		log.Warn("Could not read chain config from the db, defaulting to MainnetChainConfig", "err", err)
 		return params.MainnetChainConfig
diff --git a/cmd/rpcdaemon/commands/get_chain_config.go b/cmd/rpcdaemon/commands/get_chain_config.go
deleted file mode 100644
index c713c46d6..000000000
--- a/cmd/rpcdaemon/commands/get_chain_config.go
+++ /dev/null
@@ -1,26 +0,0 @@
-package commands
-
-import (
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/rawdb"
-	"github.com/ledgerwatch/turbo-geth/ethdb"
-	"github.com/ledgerwatch/turbo-geth/params"
-)
-
-func getChainConfig(db ethdb.Database) (*params.ChainConfig, error) {
-	cfg, _, err := getChainConfigWithGenesis(db)
-	return cfg, err
-}
-
-func getChainConfigWithGenesis(db ethdb.Database) (*params.ChainConfig, common.Hash, error) {
-	genesis, err := rawdb.ReadBlockByNumber(db, 0)
-	if err != nil {
-		return nil, common.Hash{}, err
-	}
-	genesisHash := genesis.Hash()
-	cc, err := rawdb.ReadChainConfig(db, genesisHash)
-	if err != nil {
-		return nil, common.Hash{}, err
-	}
-	return cc, genesisHash, nil
-}
diff --git a/cmd/rpcdaemon/commands/get_chain_config_test.go b/cmd/rpcdaemon/commands/get_chain_config_test.go
index 89d37b0ab..a95abb1df 100644
--- a/cmd/rpcdaemon/commands/get_chain_config_test.go
+++ b/cmd/rpcdaemon/commands/get_chain_config_test.go
@@ -14,11 +14,20 @@ func TestGetChainConfig(t *testing.T) {
 	if err != nil {
 		t.Fatalf("setting up genensis block: %v", err)
 	}
-	config1, err1 := getChainConfig(db)
+
+	api := (&BaseAPI{})
+	config1, err1 := api.chainConfig(db)
 	if err1 != nil {
 		t.Fatalf("reading chain config: %v", err1)
 	}
 	if config.String() != config1.String() {
 		t.Fatalf("read different config: %s, expected %s", config1.String(), config.String())
 	}
+	config2, err2 := api.chainConfig(db)
+	if err2 != nil {
+		t.Fatalf("reading chain config: %v", err2)
+	}
+	if config.String() != config2.String() {
+		t.Fatalf("read different config: %s, expected %s", config2.String(), config.String())
+	}
 }
diff --git a/cmd/rpcdaemon/commands/tg_api.go b/cmd/rpcdaemon/commands/tg_api.go
index 3cb9bb84e..8c7f99bfd 100644
--- a/cmd/rpcdaemon/commands/tg_api.go
+++ b/cmd/rpcdaemon/commands/tg_api.go
@@ -30,6 +30,7 @@ type TgAPI interface {
 
 // TgImpl is implementation of the TgAPI interface
 type TgImpl struct {
+	*BaseAPI
 	db       ethdb.KV
 	dbReader ethdb.Database
 }
@@ -37,6 +38,7 @@ type TgImpl struct {
 // NewTgAPI returns TgImpl instance
 func NewTgAPI(db ethdb.KV, dbReader ethdb.Database) *TgImpl {
 	return &TgImpl{
+		BaseAPI:  &BaseAPI{},
 		db:       db,
 		dbReader: dbReader,
 	}
diff --git a/cmd/rpcdaemon/commands/tg_receipts.go b/cmd/rpcdaemon/commands/tg_receipts.go
index 08fd19f21..a92ccfb16 100644
--- a/cmd/rpcdaemon/commands/tg_receipts.go
+++ b/cmd/rpcdaemon/commands/tg_receipts.go
@@ -23,7 +23,12 @@ func (api *TgImpl) GetLogsByHash(ctx context.Context, hash common.Hash) ([][]*ty
 		return nil, fmt.Errorf("block not found: %x", hash)
 	}
 
-	receipts, err := getReceipts(ctx, tx, *number, hash)
+	chainConfig, err := api.chainConfig(tx)
+	if err != nil {
+		return nil, err
+	}
+
+	receipts, err := getReceipts(ctx, tx, chainConfig, *number, hash)
 	if err != nil {
 		return nil, fmt.Errorf("getReceipts error: %v", err)
 	}
diff --git a/cmd/rpcdaemon/commands/tg_system.go b/cmd/rpcdaemon/commands/tg_system.go
index 4c5dbf1b2..90b0a12e9 100644
--- a/cmd/rpcdaemon/commands/tg_system.go
+++ b/cmd/rpcdaemon/commands/tg_system.go
@@ -22,11 +22,11 @@ func (api *TgImpl) Forks(ctx context.Context) (Forks, error) {
 	}
 	defer tx.Rollback()
 
-	chainConfig, genesisHash, err := getChainConfigWithGenesis(tx)
+	chainConfig, genesis, err := api.chainConfigWithGenesis(tx)
 	if err != nil {
 		return Forks{}, err
 	}
 	forksBlocks := forkid.GatherForks(chainConfig)
 
-	return Forks{genesisHash, forksBlocks}, nil
+	return Forks{genesis.Hash(), forksBlocks}, nil
 }
diff --git a/cmd/rpcdaemon/commands/trace_adhoc.go b/cmd/rpcdaemon/commands/trace_adhoc.go
index 9d0e06fe6..60e853300 100644
--- a/cmd/rpcdaemon/commands/trace_adhoc.go
+++ b/cmd/rpcdaemon/commands/trace_adhoc.go
@@ -268,7 +268,7 @@ func (api *TraceAPIImpl) Call(ctx context.Context, args TraceCallParam, traceTyp
 	}
 	defer dbtx.Rollback()
 
-	chainConfig, err := getChainConfig(dbtx)
+	chainConfig, err := api.chainConfig(dbtx)
 	if err != nil {
 		return nil, err
 	}
diff --git a/cmd/rpcdaemon/commands/trace_api.go b/cmd/rpcdaemon/commands/trace_api.go
index 1e8ba1f17..a64d724f1 100644
--- a/cmd/rpcdaemon/commands/trace_api.go
+++ b/cmd/rpcdaemon/commands/trace_api.go
@@ -28,6 +28,7 @@ type TraceAPI interface {
 
 // TraceAPIImpl is implementation of the TraceAPI interface based on remote Db access
 type TraceAPIImpl struct {
+	*BaseAPI
 	dbReader  ethdb.Database
 	maxTraces uint64
 	traceType string
@@ -37,6 +38,7 @@ type TraceAPIImpl struct {
 // NewTraceAPI returns NewTraceAPI instance
 func NewTraceAPI(dbReader ethdb.Database, cfg *cli.Flags) *TraceAPIImpl {
 	return &TraceAPIImpl{
+		BaseAPI:   &BaseAPI{},
 		dbReader:  dbReader,
 		maxTraces: cfg.MaxTraces,
 		traceType: cfg.TraceType,
diff --git a/cmd/rpcdaemon/commands/tracing.go b/cmd/rpcdaemon/commands/tracing.go
index 38a6d8d6d..4069230d8 100644
--- a/cmd/rpcdaemon/commands/tracing.go
+++ b/cmd/rpcdaemon/commands/tracing.go
@@ -28,7 +28,7 @@ func (api *PrivateDebugAPIImpl) TraceTransaction(ctx context.Context, hash commo
 	getter := adapter.NewBlockGetter(tx)
 	chainContext := adapter.NewChainContext(tx)
 
-	chainConfig, err := getChainConfig(tx)
+	chainConfig, err := api.chainConfig(tx)
 	if err != nil {
 		return nil, err
 	}
diff --git a/cmd/rpcdaemon/commands/web3_api.go b/cmd/rpcdaemon/commands/web3_api.go
index 9ee746b0c..751715dfa 100644
--- a/cmd/rpcdaemon/commands/web3_api.go
+++ b/cmd/rpcdaemon/commands/web3_api.go
@@ -16,11 +16,14 @@ type Web3API interface {
 }
 
 type Web3APIImpl struct {
+	*BaseAPI
 }
 
 // NewWeb3APIImpl returns Web3APIImpl instance
 func NewWeb3APIImpl() *Web3APIImpl {
-	return &Web3APIImpl{}
+	return &Web3APIImpl{
+		BaseAPI: &BaseAPI{},
+	}
 }
 
 // ClientVersion implements web3_clientVersion. Returns the current client version.
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bf83adb8a..e6ac5c77a 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -266,7 +266,7 @@ func handleOp(c ethdb.Cursor, stream remote.KV_TxServer, in *remote.Cursor) erro
 		return err
 	}
 
-	if err := stream.Send(&remote.Pair{K: common.CopyBytes(k), V: common.CopyBytes(v)}); err != nil {
+	if err := stream.Send(&remote.Pair{K: k, V: v}); err != nil {
 		return err
 	}
 
diff --git a/turbo/rpchelper/helper.go b/turbo/rpchelper/helper.go
index 1f5a54110..20dda364d 100644
--- a/turbo/rpchelper/helper.go
+++ b/turbo/rpchelper/helper.go
@@ -33,19 +33,16 @@ func GetBlockNumber(blockNrOrHash rpc.BlockNumberOrHash, dbReader ethdb.Database
 		} else {
 			blockNumber = uint64(number.Int64())
 		}
-		hash, err = GetHashByNumber(blockNumber, blockNrOrHash.RequireCanonical, dbReader)
+		hash, err = rawdb.ReadCanonicalHash(dbReader, blockNumber)
 		if err != nil {
 			return 0, common.Hash{}, err
 		}
 	} else {
-		block, err := rawdb.ReadBlockByHash(dbReader, hash)
-		if err != nil {
-			return 0, common.Hash{}, err
-		}
-		if block == nil {
+		number := rawdb.ReadHeaderNumber(dbReader, hash)
+		if number == nil {
 			return 0, common.Hash{}, fmt.Errorf("block %x not found", hash)
 		}
-		blockNumber = block.NumberU64()
+		blockNumber = *number
 
 		ch, err := rawdb.ReadCanonicalHash(dbReader, blockNumber)
 		if err != nil {
@@ -58,22 +55,7 @@ func GetBlockNumber(blockNrOrHash rpc.BlockNumberOrHash, dbReader ethdb.Database
 	return blockNumber, hash, nil
 }
 
-func GetAccount(tx ethdb.Tx, blockNumber uint64, address common.Address) (*accounts.Account, error) {
-	reader := adapter.NewStateReader(tx, blockNumber)
+func GetAccount(tx ethdb.Database, blockNumber uint64, address common.Address) (*accounts.Account, error) {
+	reader := adapter.NewStateReader(tx.(ethdb.HasTx).Tx(), blockNumber)
 	return reader.ReadAccountData(address)
 }
-
-func GetHashByNumber(blockNumber uint64, requireCanonical bool, dbReader ethdb.Database) (common.Hash, error) {
-	if requireCanonical {
-		return rawdb.ReadCanonicalHash(dbReader, blockNumber)
-	}
-
-	block, err := rawdb.ReadBlockByNumber(dbReader, blockNumber)
-	if err != nil {
-		return common.Hash{}, fmt.Errorf("block read fail: %w", err)
-	}
-	if block == nil {
-		return common.Hash{}, fmt.Errorf("block %d not found", blockNumber)
-	}
-	return block.Hash(), nil
-}
diff --git a/turbo/transactions/call.go b/turbo/transactions/call.go
index 4f2d12fff..587e839be 100644
--- a/turbo/transactions/call.go
+++ b/turbo/transactions/call.go
@@ -23,7 +23,7 @@ import (
 
 const callTimeout = 5 * time.Minute
 
-func DoCall(ctx context.Context, args ethapi.CallArgs, tx ethdb.Database, dbReader ethdb.Database, blockNrOrHash rpc.BlockNumberOrHash, overrides *map[common.Address]ethapi.Account, GasCap uint64, chainConfig *params.ChainConfig) (*core.ExecutionResult, error) {
+func DoCall(ctx context.Context, args ethapi.CallArgs, tx ethdb.Database, blockNrOrHash rpc.BlockNumberOrHash, overrides *map[common.Address]ethapi.Account, GasCap uint64, chainConfig *params.ChainConfig) (*core.ExecutionResult, error) {
 	// todo: Pending state is only known by the miner
 	/*
 		if blockNrOrHash.BlockNumber != nil && *blockNrOrHash.BlockNumber == rpc.PendingBlockNumber {
@@ -31,7 +31,7 @@ func DoCall(ctx context.Context, args ethapi.CallArgs, tx ethdb.Database, dbRead
 			return state, block.Header(), nil
 		}
 	*/
-	blockNumber, hash, err := rpchelper.GetBlockNumber(blockNrOrHash, dbReader)
+	blockNumber, hash, err := rpchelper.GetBlockNumber(blockNrOrHash, tx)
 	if err != nil {
 		return nil, err
 	}
@@ -43,7 +43,7 @@ func DoCall(ctx context.Context, args ethapi.CallArgs, tx ethdb.Database, dbRead
 	}
 	state := state.New(stateReader)
 
-	header := rawdb.ReadHeader(dbReader, hash, blockNumber)
+	header := rawdb.ReadHeader(tx, hash, blockNumber)
 	if header == nil {
 		return nil, fmt.Errorf("block %d(%x) not found", blockNumber, hash)
 	}
@@ -97,7 +97,7 @@ func DoCall(ctx context.Context, args ethapi.CallArgs, tx ethdb.Database, dbRead
 	// Get a new instance of the EVM.
 	msg := args.ToMessage(GasCap)
 
-	evmCtx := GetEvmContext(msg, header, blockNrOrHash.RequireCanonical, dbReader)
+	evmCtx := GetEvmContext(msg, header, blockNrOrHash.RequireCanonical, tx)
 
 	evm := vm.NewEVM(evmCtx, state, chainConfig, vm.Config{})
 
@@ -121,11 +121,11 @@ func DoCall(ctx context.Context, args ethapi.CallArgs, tx ethdb.Database, dbRead
 	return result, nil
 }
 
-func GetEvmContext(msg core.Message, header *types.Header, requireCanonical bool, dbReader ethdb.Database) vm.Context {
+func GetEvmContext(msg core.Message, header *types.Header, requireCanonical bool, db ethdb.Database) vm.Context {
 	return vm.Context{
 		CanTransfer: core.CanTransfer,
 		Transfer:    core.Transfer,
-		GetHash:     getHashGetter(requireCanonical, dbReader),
+		GetHash:     getHashGetter(requireCanonical, db),
 		Origin:      msg.From(),
 		Coinbase:    header.Coinbase,
 		BlockNumber: new(big.Int).Set(header.Number),
@@ -136,9 +136,9 @@ func GetEvmContext(msg core.Message, header *types.Header, requireCanonical bool
 	}
 }
 
-func getHashGetter(requireCanonical bool, dbReader ethdb.Database) func(uint64) common.Hash {
+func getHashGetter(requireCanonical bool, db ethdb.Database) func(uint64) common.Hash {
 	return func(n uint64) common.Hash {
-		hash, err := rpchelper.GetHashByNumber(n, requireCanonical, dbReader)
+		hash, err := rawdb.ReadCanonicalHash(db, n)
 		if err != nil {
 			log.Debug("can't get block hash by number", "number", n, "only-canonical", requireCanonical)
 		}
