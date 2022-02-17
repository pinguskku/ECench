commit 783e97ef1f51f4a94afbad6e07253bcdb78da2d7
Author: Sina Mahmoodi <1591639+s1na@users.noreply.github.com>
Date:   Tue Sep 28 12:54:49 2021 +0200

    core/rawdb: avoid unnecessary receipt processing for log filtering (#23147)
    
    * core/types: rm extranous check in test
    
    * core/rawdb: add lightweight types for block logs
    
    * core/rawdb,eth: use lightweight accessor for log filtering
    
    * core/rawdb: add bench for decoding into rlpLogs

diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 58226fb04..ed1c71e20 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -19,6 +19,7 @@ package rawdb
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"math/big"
 	"sort"
@@ -663,6 +664,86 @@ func DeleteReceipts(db ethdb.KeyValueWriter, hash common.Hash, number uint64) {
 	}
 }
 
+// storedReceiptRLP is the storage encoding of a receipt.
+// Re-definition in core/types/receipt.go.
+type storedReceiptRLP struct {
+	PostStateOrStatus []byte
+	CumulativeGasUsed uint64
+	Logs              []*types.LogForStorage
+}
+
+// ReceiptLogs is a barebone version of ReceiptForStorage which only keeps
+// the list of logs. When decoding a stored receipt into this object we
+// avoid creating the bloom filter.
+type receiptLogs struct {
+	Logs []*types.Log
+}
+
+// DecodeRLP implements rlp.Decoder.
+func (r *receiptLogs) DecodeRLP(s *rlp.Stream) error {
+	var stored storedReceiptRLP
+	if err := s.Decode(&stored); err != nil {
+		return err
+	}
+	r.Logs = make([]*types.Log, len(stored.Logs))
+	for i, log := range stored.Logs {
+		r.Logs[i] = (*types.Log)(log)
+	}
+	return nil
+}
+
+// DeriveLogFields fills the logs in receiptLogs with information such as block number, txhash, etc.
+func deriveLogFields(receipts []*receiptLogs, hash common.Hash, number uint64, txs types.Transactions) error {
+	logIndex := uint(0)
+	if len(txs) != len(receipts) {
+		return errors.New("transaction and receipt count mismatch")
+	}
+	for i := 0; i < len(receipts); i++ {
+		txHash := txs[i].Hash()
+		// The derived log fields can simply be set from the block and transaction
+		for j := 0; j < len(receipts[i].Logs); j++ {
+			receipts[i].Logs[j].BlockNumber = number
+			receipts[i].Logs[j].BlockHash = hash
+			receipts[i].Logs[j].TxHash = txHash
+			receipts[i].Logs[j].TxIndex = uint(i)
+			receipts[i].Logs[j].Index = logIndex
+			logIndex++
+		}
+	}
+	return nil
+}
+
+// ReadLogs retrieves the logs for all transactions in a block. The log fields
+// are populated with metadata. In case the receipts or the block body
+// are not found, a nil is returned.
+func ReadLogs(db ethdb.Reader, hash common.Hash, number uint64) [][]*types.Log {
+	// Retrieve the flattened receipt slice
+	data := ReadReceiptsRLP(db, hash, number)
+	if len(data) == 0 {
+		return nil
+	}
+	receipts := []*receiptLogs{}
+	if err := rlp.DecodeBytes(data, &receipts); err != nil {
+		log.Error("Invalid receipt array RLP", "hash", hash, "err", err)
+		return nil
+	}
+
+	body := ReadBody(db, hash, number)
+	if body == nil {
+		log.Error("Missing body but have receipt", "hash", hash, "number", number)
+		return nil
+	}
+	if err := deriveLogFields(receipts, hash, number, body.Transactions); err != nil {
+		log.Error("Failed to derive block receipts fields", "hash", hash, "number", number, "err", err)
+		return nil
+	}
+	logs := make([][]*types.Log, len(receipts))
+	for i, receipt := range receipts {
+		logs[i] = receipt.Logs
+	}
+	return logs
+}
+
 // ReadBlock retrieves an entire block corresponding to the hash, assembling it
 // back from the stored header and body. If either the header or body could not
 // be retrieved nil is returned.
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 58d7645e5..4b173c55e 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -670,3 +670,216 @@ func makeTestReceipts(n int, nPerBlock int) []types.Receipts {
 	}
 	return allReceipts
 }
+
+type fullLogRLP struct {
+	Address     common.Address
+	Topics      []common.Hash
+	Data        []byte
+	BlockNumber uint64
+	TxHash      common.Hash
+	TxIndex     uint
+	BlockHash   common.Hash
+	Index       uint
+}
+
+func newFullLogRLP(l *types.Log) *fullLogRLP {
+	return &fullLogRLP{
+		Address:     l.Address,
+		Topics:      l.Topics,
+		Data:        l.Data,
+		BlockNumber: l.BlockNumber,
+		TxHash:      l.TxHash,
+		TxIndex:     l.TxIndex,
+		BlockHash:   l.BlockHash,
+		Index:       l.Index,
+	}
+}
+
+// Tests that logs associated with a single block can be retrieved.
+func TestReadLogs(t *testing.T) {
+	db := NewMemoryDatabase()
+
+	// Create a live block since we need metadata to reconstruct the receipt
+	tx1 := types.NewTransaction(1, common.HexToAddress("0x1"), big.NewInt(1), 1, big.NewInt(1), nil)
+	tx2 := types.NewTransaction(2, common.HexToAddress("0x2"), big.NewInt(2), 2, big.NewInt(2), nil)
+
+	body := &types.Body{Transactions: types.Transactions{tx1, tx2}}
+
+	// Create the two receipts to manage afterwards
+	receipt1 := &types.Receipt{
+		Status:            types.ReceiptStatusFailed,
+		CumulativeGasUsed: 1,
+		Logs: []*types.Log{
+			{Address: common.BytesToAddress([]byte{0x11})},
+			{Address: common.BytesToAddress([]byte{0x01, 0x11})},
+		},
+		TxHash:          tx1.Hash(),
+		ContractAddress: common.BytesToAddress([]byte{0x01, 0x11, 0x11}),
+		GasUsed:         111111,
+	}
+	receipt1.Bloom = types.CreateBloom(types.Receipts{receipt1})
+
+	receipt2 := &types.Receipt{
+		PostState:         common.Hash{2}.Bytes(),
+		CumulativeGasUsed: 2,
+		Logs: []*types.Log{
+			{Address: common.BytesToAddress([]byte{0x22})},
+			{Address: common.BytesToAddress([]byte{0x02, 0x22})},
+		},
+		TxHash:          tx2.Hash(),
+		ContractAddress: common.BytesToAddress([]byte{0x02, 0x22, 0x22}),
+		GasUsed:         222222,
+	}
+	receipt2.Bloom = types.CreateBloom(types.Receipts{receipt2})
+	receipts := []*types.Receipt{receipt1, receipt2}
+
+	hash := common.BytesToHash([]byte{0x03, 0x14})
+	// Check that no receipt entries are in a pristine database
+	if rs := ReadReceipts(db, hash, 0, params.TestChainConfig); len(rs) != 0 {
+		t.Fatalf("non existent receipts returned: %v", rs)
+	}
+	// Insert the body that corresponds to the receipts
+	WriteBody(db, hash, 0, body)
+
+	// Insert the receipt slice into the database and check presence
+	WriteReceipts(db, hash, 0, receipts)
+
+	logs := ReadLogs(db, hash, 0)
+	if len(logs) == 0 {
+		t.Fatalf("no logs returned")
+	}
+	if have, want := len(logs), 2; have != want {
+		t.Fatalf("unexpected number of logs returned, have %d want %d", have, want)
+	}
+	if have, want := len(logs[0]), 2; have != want {
+		t.Fatalf("unexpected number of logs[0] returned, have %d want %d", have, want)
+	}
+	if have, want := len(logs[1]), 2; have != want {
+		t.Fatalf("unexpected number of logs[1] returned, have %d want %d", have, want)
+	}
+
+	// Fill in log fields so we can compare their rlp encoding
+	if err := types.Receipts(receipts).DeriveFields(params.TestChainConfig, hash, 0, body.Transactions); err != nil {
+		t.Fatal(err)
+	}
+	for i, pr := range receipts {
+		for j, pl := range pr.Logs {
+			rlpHave, err := rlp.EncodeToBytes(newFullLogRLP(logs[i][j]))
+			if err != nil {
+				t.Fatal(err)
+			}
+			rlpWant, err := rlp.EncodeToBytes(newFullLogRLP(pl))
+			if err != nil {
+				t.Fatal(err)
+			}
+			if !bytes.Equal(rlpHave, rlpWant) {
+				t.Fatalf("receipt #%d: receipt mismatch: have %s, want %s", i, hex.EncodeToString(rlpHave), hex.EncodeToString(rlpWant))
+			}
+		}
+	}
+}
+
+func TestDeriveLogFields(t *testing.T) {
+	// Create a few transactions to have receipts for
+	to2 := common.HexToAddress("0x2")
+	to3 := common.HexToAddress("0x3")
+	txs := types.Transactions{
+		types.NewTx(&types.LegacyTx{
+			Nonce:    1,
+			Value:    big.NewInt(1),
+			Gas:      1,
+			GasPrice: big.NewInt(1),
+		}),
+		types.NewTx(&types.LegacyTx{
+			To:       &to2,
+			Nonce:    2,
+			Value:    big.NewInt(2),
+			Gas:      2,
+			GasPrice: big.NewInt(2),
+		}),
+		types.NewTx(&types.AccessListTx{
+			To:       &to3,
+			Nonce:    3,
+			Value:    big.NewInt(3),
+			Gas:      3,
+			GasPrice: big.NewInt(3),
+		}),
+	}
+	// Create the corresponding receipts
+	receipts := []*receiptLogs{
+		{
+			Logs: []*types.Log{
+				{Address: common.BytesToAddress([]byte{0x11})},
+				{Address: common.BytesToAddress([]byte{0x01, 0x11})},
+			},
+		},
+		{
+			Logs: []*types.Log{
+				{Address: common.BytesToAddress([]byte{0x22})},
+				{Address: common.BytesToAddress([]byte{0x02, 0x22})},
+			},
+		},
+		{
+			Logs: []*types.Log{
+				{Address: common.BytesToAddress([]byte{0x33})},
+				{Address: common.BytesToAddress([]byte{0x03, 0x33})},
+			},
+		},
+	}
+
+	// Derive log metadata fields
+	number := big.NewInt(1)
+	hash := common.BytesToHash([]byte{0x03, 0x14})
+	if err := deriveLogFields(receipts, hash, number.Uint64(), txs); err != nil {
+		t.Fatal(err)
+	}
+
+	// Iterate over all the computed fields and check that they're correct
+	logIndex := uint(0)
+	for i := range receipts {
+		for j := range receipts[i].Logs {
+			if receipts[i].Logs[j].BlockNumber != number.Uint64() {
+				t.Errorf("receipts[%d].Logs[%d].BlockNumber = %d, want %d", i, j, receipts[i].Logs[j].BlockNumber, number.Uint64())
+			}
+			if receipts[i].Logs[j].BlockHash != hash {
+				t.Errorf("receipts[%d].Logs[%d].BlockHash = %s, want %s", i, j, receipts[i].Logs[j].BlockHash.String(), hash.String())
+			}
+			if receipts[i].Logs[j].TxHash != txs[i].Hash() {
+				t.Errorf("receipts[%d].Logs[%d].TxHash = %s, want %s", i, j, receipts[i].Logs[j].TxHash.String(), txs[i].Hash().String())
+			}
+			if receipts[i].Logs[j].TxIndex != uint(i) {
+				t.Errorf("receipts[%d].Logs[%d].TransactionIndex = %d, want %d", i, j, receipts[i].Logs[j].TxIndex, i)
+			}
+			if receipts[i].Logs[j].Index != logIndex {
+				t.Errorf("receipts[%d].Logs[%d].Index = %d, want %d", i, j, receipts[i].Logs[j].Index, logIndex)
+			}
+			logIndex++
+		}
+	}
+}
+
+func BenchmarkDecodeRLPLogs(b *testing.B) {
+	// Encoded receipts from block 0x14ee094309fbe8f70b65f45ebcc08fb33f126942d97464aad5eb91cfd1e2d269
+	buf, err := ioutil.ReadFile("testdata/stored_receipts.bin")
+	if err != nil {
+		b.Fatal(err)
+	}
+	b.Run("ReceiptForStorage", func(b *testing.B) {
+		b.ReportAllocs()
+		var r []*types.ReceiptForStorage
+		for i := 0; i < b.N; i++ {
+			if err := rlp.DecodeBytes(buf, &r); err != nil {
+				b.Fatal(err)
+			}
+		}
+	})
+	b.Run("rlpLogs", func(b *testing.B) {
+		b.ReportAllocs()
+		var r []*receiptLogs
+		for i := 0; i < b.N; i++ {
+			if err := rlp.DecodeBytes(buf, &r); err != nil {
+				b.Fatal(err)
+			}
+		}
+	})
+}
diff --git a/core/rawdb/testdata/stored_receipts.bin b/core/rawdb/testdata/stored_receipts.bin
new file mode 100644
index 000000000..8204fae09
Binary files /dev/null and b/core/rawdb/testdata/stored_receipts.bin differ
diff --git a/core/types/receipt_test.go b/core/types/receipt_test.go
index 22a316c23..492493d5c 100644
--- a/core/types/receipt_test.go
+++ b/core/types/receipt_test.go
@@ -273,9 +273,6 @@ func TestDeriveFields(t *testing.T) {
 			if receipts[i].Logs[j].TxHash != txs[i].Hash() {
 				t.Errorf("receipts[%d].Logs[%d].TxHash = %s, want %s", i, j, receipts[i].Logs[j].TxHash.String(), txs[i].Hash().String())
 			}
-			if receipts[i].Logs[j].TxHash != txs[i].Hash() {
-				t.Errorf("receipts[%d].Logs[%d].TxHash = %s, want %s", i, j, receipts[i].Logs[j].TxHash.String(), txs[i].Hash().String())
-			}
 			if receipts[i].Logs[j].TxIndex != uint(i) {
 				t.Errorf("receipts[%d].Logs[%d].TransactionIndex = %d, want %d", i, j, receipts[i].Logs[j].TxIndex, i)
 			}
diff --git a/eth/api_backend.go b/eth/api_backend.go
index 7b40a7edd..1af33414c 100644
--- a/eth/api_backend.go
+++ b/eth/api_backend.go
@@ -181,13 +181,14 @@ func (b *EthAPIBackend) GetReceipts(ctx context.Context, hash common.Hash) (type
 }
 
 func (b *EthAPIBackend) GetLogs(ctx context.Context, hash common.Hash) ([][]*types.Log, error) {
-	receipts := b.eth.blockchain.GetReceiptsByHash(hash)
-	if receipts == nil {
-		return nil, nil
+	db := b.eth.ChainDb()
+	number := rawdb.ReadHeaderNumber(db, hash)
+	if number == nil {
+		return nil, errors.New("failed to get block number from hash")
 	}
-	logs := make([][]*types.Log, len(receipts))
-	for i, receipt := range receipts {
-		logs[i] = receipt.Logs
+	logs := rawdb.ReadLogs(db, hash, *number)
+	if logs == nil {
+		return nil, errors.New("failed to get logs for block")
 	}
 	return logs, nil
 }
