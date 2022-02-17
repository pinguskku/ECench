commit 7fd0ccaa68cbc8e3f4fc59d3b99ba5067ba7c73a
Author: Gary Rong <garyrong0905@gmail.com>
Date:   Thu Feb 21 21:14:35 2019 +0800

    core: remove unnecessary fields in logs, receipts and tx lookups (#17106)
    
    * core: remove unnecessary fields in log
    
    * core: bump blockchain database version
    
    * core, les: remove unnecessary fields in txlookup
    
    * eth: print db version explicitly
    
    * core/rawdb: drop txlookup entry struct wrapper

diff --git a/core/blockchain.go b/core/blockchain.go
index a3121cfd3..d6dad2799 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -65,7 +65,13 @@ const (
 	triesInMemory       = 128
 
 	// BlockChainVersion ensures that an incompatible database forces a resync from scratch.
-	BlockChainVersion uint64 = 3
+	//
+	// During the process of upgrading the database version from 3 to 4,
+	// the following incompatible database changes were added.
+	// * the `BlockNumber`, `TxHash`, `TxIndex`, `BlockHash` and `Index` fields of log are deleted
+	// * the `Bloom` field of receipt is deleted
+	// * the `BlockIndex` and `TxIndex` fields of txlookup are deleted
+	BlockChainVersion uint64 = 4
 )
 
 // CacheConfig contains the configuration values for the trie caching/pruning
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 491a125c6..8a95dafe9 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -294,7 +294,17 @@ func ReadReceipts(db DatabaseReader, hash common.Hash, number uint64) types.Rece
 		return nil
 	}
 	receipts := make(types.Receipts, len(storageReceipts))
+	logIndex := uint(0)
 	for i, receipt := range storageReceipts {
+		// Assemble deriving fields for log.
+		for _, log := range receipt.Logs {
+			log.TxHash = receipt.TxHash
+			log.BlockHash = hash
+			log.BlockNumber = number
+			log.TxIndex = uint(i)
+			log.Index = logIndex
+			logIndex += 1
+		}
 		receipts[i] = (*types.Receipt)(receipt)
 	}
 	return receipts
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index fcc36dc2b..37e0d4fda 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -279,6 +279,7 @@ func TestBlockReceiptStorage(t *testing.T) {
 		ContractAddress: common.BytesToAddress([]byte{0x01, 0x11, 0x11}),
 		GasUsed:         111111,
 	}
+	receipt1.Bloom = types.CreateBloom(types.Receipts{receipt1})
 	receipt2 := &types.Receipt{
 		PostState:         common.Hash{2}.Bytes(),
 		CumulativeGasUsed: 2,
@@ -290,6 +291,7 @@ func TestBlockReceiptStorage(t *testing.T) {
 		ContractAddress: common.BytesToAddress([]byte{0x02, 0x22, 0x22}),
 		GasUsed:         222222,
 	}
+	receipt2.Bloom = types.CreateBloom(types.Receipts{receipt2})
 	receipts := []*types.Receipt{receipt1, receipt2}
 
 	// Check that no receipt entries are in a pristine database
diff --git a/core/rawdb/accessors_indexes.go b/core/rawdb/accessors_indexes.go
index 4ff7e5bd3..e6f7782a1 100644
--- a/core/rawdb/accessors_indexes.go
+++ b/core/rawdb/accessors_indexes.go
@@ -25,33 +25,28 @@ import (
 
 // ReadTxLookupEntry retrieves the positional metadata associated with a transaction
 // hash to allow retrieving the transaction or receipt by hash.
-func ReadTxLookupEntry(db DatabaseReader, hash common.Hash) (common.Hash, uint64, uint64) {
+func ReadTxLookupEntry(db DatabaseReader, hash common.Hash) common.Hash {
 	data, _ := db.Get(txLookupKey(hash))
 	if len(data) == 0 {
-		return common.Hash{}, 0, 0
+		return common.Hash{}
 	}
-	var entry TxLookupEntry
+	if len(data) == common.HashLength {
+		return common.BytesToHash(data)
+	}
+	// Probably it's legacy txlookup entry data, try to decode it.
+	var entry LegacyTxLookupEntry
 	if err := rlp.DecodeBytes(data, &entry); err != nil {
-		log.Error("Invalid transaction lookup entry RLP", "hash", hash, "err", err)
-		return common.Hash{}, 0, 0
+		log.Error("Invalid transaction lookup entry RLP", "hash", hash, "blob", data, "err", err)
+		return common.Hash{}
 	}
-	return entry.BlockHash, entry.BlockIndex, entry.Index
+	return entry.BlockHash
 }
 
 // WriteTxLookupEntries stores a positional metadata for every transaction from
 // a block, enabling hash based transaction and receipt lookups.
 func WriteTxLookupEntries(db DatabaseWriter, block *types.Block) {
-	for i, tx := range block.Transactions() {
-		entry := TxLookupEntry{
-			BlockHash:  block.Hash(),
-			BlockIndex: block.NumberU64(),
-			Index:      uint64(i),
-		}
-		data, err := rlp.EncodeToBytes(entry)
-		if err != nil {
-			log.Crit("Failed to encode transaction lookup entry", "err", err)
-		}
-		if err := db.Put(txLookupKey(tx.Hash()), data); err != nil {
+	for _, tx := range block.Transactions() {
+		if err := db.Put(txLookupKey(tx.Hash()), block.Hash().Bytes()); err != nil {
 			log.Crit("Failed to store transaction lookup entry", "err", err)
 		}
 	}
@@ -65,31 +60,47 @@ func DeleteTxLookupEntry(db DatabaseDeleter, hash common.Hash) {
 // ReadTransaction retrieves a specific transaction from the database, along with
 // its added positional metadata.
 func ReadTransaction(db DatabaseReader, hash common.Hash) (*types.Transaction, common.Hash, uint64, uint64) {
-	blockHash, blockNumber, txIndex := ReadTxLookupEntry(db, hash)
+	blockHash := ReadTxLookupEntry(db, hash)
 	if blockHash == (common.Hash{}) {
 		return nil, common.Hash{}, 0, 0
 	}
-	body := ReadBody(db, blockHash, blockNumber)
-	if body == nil || len(body.Transactions) <= int(txIndex) {
-		log.Error("Transaction referenced missing", "number", blockNumber, "hash", blockHash, "index", txIndex)
+	blockNumber := ReadHeaderNumber(db, blockHash)
+	if blockNumber == nil {
+		return nil, common.Hash{}, 0, 0
+	}
+	body := ReadBody(db, blockHash, *blockNumber)
+	if body == nil {
+		log.Error("Transaction referenced missing", "number", blockNumber, "hash", blockHash)
 		return nil, common.Hash{}, 0, 0
 	}
-	return body.Transactions[txIndex], blockHash, blockNumber, txIndex
+	for txIndex, tx := range body.Transactions {
+		if tx.Hash() == hash {
+			return tx, blockHash, *blockNumber, uint64(txIndex)
+		}
+	}
+	log.Error("Transaction not found", "number", blockNumber, "hash", blockHash, "txhash", hash)
+	return nil, common.Hash{}, 0, 0
 }
 
 // ReadReceipt retrieves a specific transaction receipt from the database, along with
 // its added positional metadata.
 func ReadReceipt(db DatabaseReader, hash common.Hash) (*types.Receipt, common.Hash, uint64, uint64) {
-	blockHash, blockNumber, receiptIndex := ReadTxLookupEntry(db, hash)
+	blockHash := ReadTxLookupEntry(db, hash)
 	if blockHash == (common.Hash{}) {
 		return nil, common.Hash{}, 0, 0
 	}
-	receipts := ReadReceipts(db, blockHash, blockNumber)
-	if len(receipts) <= int(receiptIndex) {
-		log.Error("Receipt refereced missing", "number", blockNumber, "hash", blockHash, "index", receiptIndex)
+	blockNumber := ReadHeaderNumber(db, blockHash)
+	if blockNumber == nil {
 		return nil, common.Hash{}, 0, 0
 	}
-	return receipts[receiptIndex], blockHash, blockNumber, receiptIndex
+	receipts := ReadReceipts(db, blockHash, *blockNumber)
+	for receiptIndex, receipt := range receipts {
+		if receipt.TxHash == hash {
+			return receipt, blockHash, *blockNumber, uint64(receiptIndex)
+		}
+	}
+	log.Error("Receipt not found", "number", blockNumber, "hash", blockHash, "txhash", hash)
+	return nil, common.Hash{}, 0, 0
 }
 
 // ReadBloomBits retrieves the compressed bloom bit vector belonging to the given
diff --git a/core/rawdb/accessors_indexes_test.go b/core/rawdb/accessors_indexes_test.go
index d9c10e149..bed03a5e6 100644
--- a/core/rawdb/accessors_indexes_test.go
+++ b/core/rawdb/accessors_indexes_test.go
@@ -23,6 +23,7 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/ethdb"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // Tests that positional lookup metadata can be stored and retrieved.
@@ -65,4 +66,26 @@ func TestLookupStorage(t *testing.T) {
 			t.Fatalf("tx #%d [%x]: deleted transaction returned: %v", i, tx.Hash(), txn)
 		}
 	}
+	// Insert legacy txlookup and verify the data retrieval
+	for index, tx := range block.Transactions() {
+		entry := LegacyTxLookupEntry{
+			BlockHash:  block.Hash(),
+			BlockIndex: block.NumberU64(),
+			Index:      uint64(index),
+		}
+		data, _ := rlp.EncodeToBytes(entry)
+		db.Put(txLookupKey(tx.Hash()), data)
+	}
+	for i, tx := range txs {
+		if txn, hash, number, index := ReadTransaction(db, tx.Hash()); txn == nil {
+			t.Fatalf("tx #%d [%x]: transaction not found", i, tx.Hash())
+		} else {
+			if hash != block.Hash() || number != block.NumberU64() || index != uint64(i) {
+				t.Fatalf("tx #%d [%x]: positional metadata mismatch: have %x/%d/%d, want %x/%v/%v", i, tx.Hash(), hash, number, index, block.Hash(), block.NumberU64(), i)
+			}
+			if tx.Hash() != txn.Hash() {
+				t.Fatalf("tx #%d [%x]: transaction mismatch: have %v, want %v", i, tx.Hash(), txn, tx)
+			}
+		}
+	}
 }
diff --git a/core/rawdb/schema.go b/core/rawdb/schema.go
index 8a9921ef4..3bb86e7ff 100644
--- a/core/rawdb/schema.go
+++ b/core/rawdb/schema.go
@@ -63,9 +63,9 @@ var (
 	preimageHitCounter = metrics.NewRegisteredCounter("db/preimage/hits", nil)
 )
 
-// TxLookupEntry is a positional metadata to help looking up the data content of
-// a transaction or receipt given only its hash.
-type TxLookupEntry struct {
+// LegacyTxLookupEntry is the legacy TxLookupEntry definition with some unnecessary
+// fields.
+type LegacyTxLookupEntry struct {
 	BlockHash  common.Hash
 	BlockIndex uint64
 	Index      uint64
diff --git a/core/types/gen_log_json.go b/core/types/gen_log_json.go
index 1b5ae3c65..6e9433947 100644
--- a/core/types/gen_log_json.go
+++ b/core/types/gen_log_json.go
@@ -12,6 +12,7 @@ import (
 
 var _ = (*logMarshaling)(nil)
 
+// MarshalJSON marshals as JSON.
 func (l Log) MarshalJSON() ([]byte, error) {
 	type Log struct {
 		Address     common.Address `json:"address" gencodec:"required"`
@@ -37,6 +38,7 @@ func (l Log) MarshalJSON() ([]byte, error) {
 	return json.Marshal(&enc)
 }
 
+// UnmarshalJSON unmarshals from JSON.
 func (l *Log) UnmarshalJSON(input []byte) error {
 	type Log struct {
 		Address     *common.Address `json:"address" gencodec:"required"`
diff --git a/core/types/log.go b/core/types/log.go
index 717cd2e5a..a395d5a67 100644
--- a/core/types/log.go
+++ b/core/types/log.go
@@ -68,7 +68,11 @@ type rlpLog struct {
 	Data    []byte
 }
 
-type rlpStorageLog struct {
+// rlpStorageLog is the storage encoding of a log.
+type rlpStorageLog rlpLog
+
+// LegacyRlpStorageLog is the previous storage encoding of a log including some redundant fields.
+type LegacyRlpStorageLog struct {
 	Address     common.Address
 	Topics      []common.Hash
 	Data        []byte
@@ -101,31 +105,34 @@ type LogForStorage Log
 // EncodeRLP implements rlp.Encoder.
 func (l *LogForStorage) EncodeRLP(w io.Writer) error {
 	return rlp.Encode(w, rlpStorageLog{
-		Address:     l.Address,
-		Topics:      l.Topics,
-		Data:        l.Data,
-		BlockNumber: l.BlockNumber,
-		TxHash:      l.TxHash,
-		TxIndex:     l.TxIndex,
-		BlockHash:   l.BlockHash,
-		Index:       l.Index,
+		Address: l.Address,
+		Topics:  l.Topics,
+		Data:    l.Data,
 	})
 }
 
 // DecodeRLP implements rlp.Decoder.
+//
+// Note some redundant fields(e.g. block number, tx hash etc) will be assembled later.
 func (l *LogForStorage) DecodeRLP(s *rlp.Stream) error {
 	var dec rlpStorageLog
 	err := s.Decode(&dec)
 	if err == nil {
 		*l = LogForStorage{
-			Address:     dec.Address,
-			Topics:      dec.Topics,
-			Data:        dec.Data,
-			BlockNumber: dec.BlockNumber,
-			TxHash:      dec.TxHash,
-			TxIndex:     dec.TxIndex,
-			BlockHash:   dec.BlockHash,
-			Index:       dec.Index,
+			Address: dec.Address,
+			Topics:  dec.Topics,
+			Data:    dec.Data,
+		}
+	} else {
+		// Try to decode log with previous definition.
+		var dec LegacyRlpStorageLog
+		err = s.Decode(&dec)
+		if err == nil {
+			*l = LogForStorage{
+				Address: dec.Address,
+				Topics:  dec.Topics,
+				Data:    dec.Data,
+			}
 		}
 	}
 	return err
diff --git a/core/types/receipt.go b/core/types/receipt.go
index 3d1fc95aa..ac1ebe349 100644
--- a/core/types/receipt.go
+++ b/core/types/receipt.go
@@ -72,7 +72,18 @@ type receiptRLP struct {
 	Logs              []*Log
 }
 
+// receiptStorageRLP is the storage encoding of a receipt.
 type receiptStorageRLP struct {
+	PostStateOrStatus []byte
+	CumulativeGasUsed uint64
+	TxHash            common.Hash
+	ContractAddress   common.Address
+	Logs              []*LogForStorage
+	GasUsed           uint64
+}
+
+// LegacyReceiptStorageRLP is the previous storage encoding of a receipt including some unnecessary fields.
+type LegacyReceiptStorageRLP struct {
 	PostStateOrStatus []byte
 	CumulativeGasUsed uint64
 	Bloom             Bloom
@@ -159,7 +170,6 @@ func (r *ReceiptForStorage) EncodeRLP(w io.Writer) error {
 	enc := &receiptStorageRLP{
 		PostStateOrStatus: (*Receipt)(r).statusEncoding(),
 		CumulativeGasUsed: r.CumulativeGasUsed,
-		Bloom:             r.Bloom,
 		TxHash:            r.TxHash,
 		ContractAddress:   r.ContractAddress,
 		Logs:              make([]*LogForStorage, len(r.Logs)),
@@ -176,17 +186,28 @@ func (r *ReceiptForStorage) EncodeRLP(w io.Writer) error {
 func (r *ReceiptForStorage) DecodeRLP(s *rlp.Stream) error {
 	var dec receiptStorageRLP
 	if err := s.Decode(&dec); err != nil {
-		return err
+		var sdec LegacyReceiptStorageRLP
+		if err := s.Decode(&sdec); err != nil {
+			return err
+		}
+		dec.PostStateOrStatus = common.CopyBytes(sdec.PostStateOrStatus)
+		dec.CumulativeGasUsed = sdec.CumulativeGasUsed
+		dec.TxHash = sdec.TxHash
+		dec.ContractAddress = sdec.ContractAddress
+		dec.Logs = sdec.Logs
+		dec.GasUsed = sdec.GasUsed
 	}
 	if err := (*Receipt)(r).setStatus(dec.PostStateOrStatus); err != nil {
 		return err
 	}
 	// Assign the consensus fields
-	r.CumulativeGasUsed, r.Bloom = dec.CumulativeGasUsed, dec.Bloom
+	r.CumulativeGasUsed = dec.CumulativeGasUsed
 	r.Logs = make([]*Log, len(dec.Logs))
 	for i, log := range dec.Logs {
 		r.Logs[i] = (*Log)(log)
 	}
+
+	r.Bloom = CreateBloom(Receipts{(*Receipt)(r)})
 	// Assign the implementation fields
 	r.TxHash, r.ContractAddress, r.GasUsed = dec.TxHash, dec.ContractAddress, dec.GasUsed
 	return nil
diff --git a/eth/backend.go b/eth/backend.go
index 6a136182a..6710e4513 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -145,16 +145,20 @@ func New(ctx *node.ServiceContext, config *Config) (*Ethereum, error) {
 		bloomIndexer:   NewBloomIndexer(chainDb, params.BloomBitsBlocks, params.BloomConfirms),
 	}
 
-	log.Info("Initialising Ethereum protocol", "versions", ProtocolVersions, "network", config.NetworkId)
+	bcVersion := rawdb.ReadDatabaseVersion(chainDb)
+	var dbVer = "<nil>"
+	if bcVersion != nil {
+		dbVer = fmt.Sprintf("%d", *bcVersion)
+	}
+	log.Info("Initialising Ethereum protocol", "versions", ProtocolVersions, "network", config.NetworkId, "dbversion", dbVer)
 
 	if !config.SkipBcVersionCheck {
-		bcVersion := rawdb.ReadDatabaseVersion(chainDb)
 		if bcVersion != nil && *bcVersion > core.BlockChainVersion {
 			return nil, fmt.Errorf("database version is v%d, Geth %s only supports v%d", *bcVersion, params.VersionWithMeta, core.BlockChainVersion)
-		} else if bcVersion != nil && *bcVersion < core.BlockChainVersion {
-			log.Warn("Upgrade blockchain database version", "from", *bcVersion, "to", core.BlockChainVersion)
+		} else if bcVersion == nil || *bcVersion < core.BlockChainVersion {
+			log.Warn("Upgrade blockchain database version", "from", dbVer, "to", core.BlockChainVersion)
+			rawdb.WriteDatabaseVersion(chainDb, core.BlockChainVersion)
 		}
-		rawdb.WriteDatabaseVersion(chainDb, core.BlockChainVersion)
 	}
 	var (
 		vmConfig = vm.Config{
diff --git a/les/handler.go b/les/handler.go
index 46a1ed2d7..680e115b0 100644
--- a/les/handler.go
+++ b/les/handler.go
@@ -1193,9 +1193,9 @@ func (pm *ProtocolManager) txStatus(hashes []common.Hash) []txStatus {
 
 		// If the transaction is unknown to the pool, try looking it up locally
 		if stat == core.TxStatusUnknown {
-			if block, number, index := rawdb.ReadTxLookupEntry(pm.chainDb, hashes[i]); block != (common.Hash{}) {
+			if tx, blockHash, blockNumber, txIndex := rawdb.ReadTransaction(pm.chainDb, hashes[i]); tx != nil {
 				stats[i].Status = core.TxStatusIncluded
-				stats[i].Lookup = &rawdb.TxLookupEntry{BlockHash: block, BlockIndex: number, Index: index}
+				stats[i].Lookup = &rawdb.LegacyTxLookupEntry{BlockHash: blockHash, BlockIndex: blockNumber, Index: txIndex}
 			}
 		}
 	}
diff --git a/les/handler_test.go b/les/handler_test.go
index 72ba266b3..e9033729e 100644
--- a/les/handler_test.go
+++ b/les/handler_test.go
@@ -559,8 +559,8 @@ func TestTransactionStatusLes2(t *testing.T) {
 
 	// check if their status is included now
 	block1hash := rawdb.ReadCanonicalHash(db, 1)
-	test(tx1, false, txStatus{Status: core.TxStatusIncluded, Lookup: &rawdb.TxLookupEntry{BlockHash: block1hash, BlockIndex: 1, Index: 0}})
-	test(tx2, false, txStatus{Status: core.TxStatusIncluded, Lookup: &rawdb.TxLookupEntry{BlockHash: block1hash, BlockIndex: 1, Index: 1}})
+	test(tx1, false, txStatus{Status: core.TxStatusIncluded, Lookup: &rawdb.LegacyTxLookupEntry{BlockHash: block1hash, BlockIndex: 1, Index: 0}})
+	test(tx2, false, txStatus{Status: core.TxStatusIncluded, Lookup: &rawdb.LegacyTxLookupEntry{BlockHash: block1hash, BlockIndex: 1, Index: 1}})
 
 	// create a reorg that rolls them back
 	gchain, _ = core.GenerateChain(params.TestChainConfig, chain.GetBlockByNumber(0), ethash.NewFaker(), db, 2, func(i int, block *core.BlockGen) {})
diff --git a/les/protocol.go b/les/protocol.go
index 0b24f5aed..b75f92bf7 100644
--- a/les/protocol.go
+++ b/les/protocol.go
@@ -221,6 +221,6 @@ type proofsData [][]rlp.RawValue
 
 type txStatus struct {
 	Status core.TxStatus
-	Lookup *rawdb.TxLookupEntry `rlp:"nil"`
+	Lookup *rawdb.LegacyTxLookupEntry `rlp:"nil"`
 	Error  string
 }
