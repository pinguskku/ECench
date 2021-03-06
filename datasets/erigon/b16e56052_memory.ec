commit b16e56052933439c89e61e312fece1c55cdeb7c2
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Mon May 25 13:12:25 2020 +0200

    Use uint256.Int rather than common.Hash for storage values to reduce memory allocation in opSload & opSstore (#575)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload
    
    * Use uint256.Int rather than common.Hash for storage values to reduce memory allocation in opSload & opSstore
    
    * linter
    
    * linters
    
    * small clean up

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index f16bc774c..83b65ac67 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -24,6 +24,8 @@ import (
 	"sync"
 	"time"
 
+	"github.com/holiman/uint256"
+
 	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
@@ -235,9 +237,9 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	var val common.Hash
+	var val uint256.Int
 	statedb.GetState(contract, &key, &val)
-	return val[:], nil
+	return val.Bytes(), nil
 }
 
 // TransactionReceipt returns the receipt of a transaction.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 2b6599f31..c6ca4af87 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,7 @@ import (
 	"testing"
 	"time"
 
+	"github.com/holiman/uint256"
 	"github.com/stretchr/testify/assert"
 
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -2763,26 +2764,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 
 	// If all is correct, then slot 1 and 2 are zero
 	key1 := common.HexToHash("01")
-	var got common.Hash
+	var got uint256.Int
 	statedb.GetState(aa, &key1, &got)
-	if exp := (common.Hash{}); got != exp {
-		t.Errorf("got %x exp %x", got, exp)
+	if !got.IsZero() {
+		t.Errorf("got %x exp %x", got, 0)
 	}
 	key2 := common.HexToHash("02")
 	statedb.GetState(aa, &key2, &got)
-	if exp := (common.Hash{}); got != exp {
-		t.Errorf("got %x exp %x", got, exp)
+	if !got.IsZero() {
+		t.Errorf("got %x exp %x", got, 0)
 	}
 	// Also, 3 and 4 should be set
 	key3 := common.HexToHash("03")
 	statedb.GetState(aa, &key3, &got)
-	if exp := common.HexToHash("03"); got != exp {
-		t.Fatalf("got %x exp %x", got, exp)
+	if got.Uint64() != 3 {
+		t.Fatalf("got %x exp %x", got, 3)
 	}
 	key4 := common.HexToHash("04")
 	statedb.GetState(aa, &key4, &got)
-	if exp := common.HexToHash("04"); got != exp {
-		t.Fatalf("got %x exp %x", got, exp)
+	if got.Uint64() != 4 {
+		t.Fatalf("got %x exp %x", got, 4)
 	}
 }
 
@@ -2860,15 +2861,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 
 	// If all is correct, then both slots are zero
 	key1 := common.HexToHash("01")
-	var got common.Hash
+	var got uint256.Int
 	statedb.GetState(aa, &key1, &got)
-	if exp := (common.Hash{}); got != exp {
-		t.Errorf("got %x exp %x", got, exp)
+	if !got.IsZero() {
+		t.Errorf("got %x exp %x", got, 0)
 	}
 	key2 := common.HexToHash("02")
 	statedb.GetState(aa, &key2, &got)
-	if exp := (common.Hash{}); got != exp {
-		t.Errorf("got %x exp %x", got, exp)
+	if !got.IsZero() {
+		t.Errorf("got %x exp %x", got, 0)
 	}
 }
 
@@ -3053,15 +3054,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
 		key1 := common.HexToHash("01")
-		var got common.Hash
+		var got uint256.Int
 		statedb.GetState(aa, &key1, &got)
-		if exp := (common.Hash{}); got != exp {
-			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
+		if !got.IsZero() {
+			t.Errorf("block %d, got %x exp %x", blockNum, got, 0)
 		}
 		key2 := common.HexToHash("02")
 		statedb.GetState(aa, &key2, &got)
-		if exp := (common.Hash{}); got != exp {
-			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
+		if !got.IsZero() {
+			t.Errorf("block %d, got %x exp %x", blockNum, got, 0)
 		}
 		exp := expectations[i]
 		if exp.exist {
@@ -3070,10 +3071,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 			}
 			for slot, val := range exp.values {
 				key := asHash(slot)
-				var gotValue common.Hash
+				var gotValue uint256.Int
 				statedb.GetState(aa, &key, &gotValue)
-				if expValue := asHash(val); gotValue != expValue {
-					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
+				if gotValue.Uint64() != uint64(val) {
+					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, val)
 				}
 			}
 		} else {
diff --git a/core/genesis.go b/core/genesis.go
index 7d98bd2bf..488ac7839 100644
--- a/core/genesis.go
+++ b/core/genesis.go
@@ -18,6 +18,7 @@ package core
 
 import (
 	"bytes"
+	"context"
 	"encoding/hex"
 	"encoding/json"
 	"errors"
@@ -25,7 +26,7 @@ import (
 	"math/big"
 	"strings"
 
-	"context"
+	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -41,7 +42,7 @@ import (
 )
 
 var UsePlainStateExecution = false // FIXME: when we can move the hashed state forward.
-//  ^--- will be overriden e when parsing flags anyway
+//  ^--- will be overridden when parsing flags anyway
 
 //go:generate gencodec -type Genesis -field-override genesisSpecMarshaling -out gen_genesis.go
 //go:generate gencodec -type GenesisAccount -field-override genesisAccountMarshaling -out gen_genesis_account.go
@@ -253,7 +254,9 @@ func (g *Genesis) ToBlock(db ethdb.Database, history bool) (*types.Block, *state
 		statedb.SetCode(addr, account.Code)
 		statedb.SetNonce(addr, account.Nonce)
 		for key, value := range account.Storage {
-			statedb.SetState(addr, key, value)
+			key := key
+			val := uint256.NewInt().SetBytes(value.Bytes())
+			statedb.SetState(addr, &key, *val)
 		}
 
 		if len(account.Code) > 0 || len(account.Storage) > 0 {
diff --git a/core/state/change_set_writer.go b/core/state/change_set_writer.go
index 7135bc2ce..fc457ea1b 100644
--- a/core/state/change_set_writer.go
+++ b/core/state/change_set_writer.go
@@ -4,6 +4,8 @@ import (
 	"context"
 	"fmt"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/changeset"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
@@ -139,7 +141,7 @@ func (w *ChangeSetWriter) DeleteAccount(ctx context.Context, address common.Addr
 	return nil
 }
 
-func (w *ChangeSetWriter) WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (w *ChangeSetWriter) WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	if *original == *value {
 		return nil
 	}
@@ -149,11 +151,7 @@ func (w *ChangeSetWriter) WriteAccountStorage(ctx context.Context, address commo
 		return err
 	}
 
-	o := cleanUpTrailingZeroes(original[:])
-	originalValue := make([]byte, len(o))
-	copy(originalValue, o)
-
-	w.storageChanges[string(compositeKey)] = originalValue
+	w.storageChanges[string(compositeKey)] = original.Bytes()
 	w.storageChanged[address] = true
 
 	return nil
diff --git a/core/state/database.go b/core/state/database.go
index 65bb58a4b..4f64d8baa 100644
--- a/core/state/database.go
+++ b/core/state/database.go
@@ -28,6 +28,8 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -61,7 +63,7 @@ type StateWriter interface {
 	UpdateAccountData(ctx context.Context, address common.Address, original, account *accounts.Account) error
 	UpdateAccountCode(address common.Address, incarnation uint64, codeHash common.Hash, code []byte) error
 	DeleteAccount(ctx context.Context, address common.Address, original *accounts.Account) error
-	WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error
+	WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error
 	CreateContract(address common.Address) error
 }
 
@@ -89,7 +91,7 @@ func (nw *NoopWriter) UpdateAccountCode(address common.Address, incarnation uint
 	return nil
 }
 
-func (nw *NoopWriter) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (nw *NoopWriter) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	return nil
 }
 
@@ -97,7 +99,7 @@ func (nw *NoopWriter) CreateContract(address common.Address) error {
 	return nil
 }
 
-// Structure holding updates, deletes, and reads registered within one change period
+// Buffer is a structure holding updates, deletes, and reads registered within one change period
 // A change period can be transaction within a block, or a block within group of blocks
 type Buffer struct {
 	codeReads     map[common.Hash]common.Hash
@@ -1350,13 +1352,13 @@ func (tsw *TrieStateWriter) UpdateAccountCode(address common.Address, incarnatio
 	return nil
 }
 
-func (tsw *TrieStateWriter) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (tsw *TrieStateWriter) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	addrHash, err := tsw.tds.pw.HashAddress(address, false /*save*/)
 	if err != nil {
 		return err
 	}
 
-	v := bytes.TrimLeft(value[:], "\x00")
+	v := value.Bytes()
 	m, ok := tsw.tds.currentBuffer.storageUpdates[addrHash]
 	if !ok {
 		m = make(map[common.Hash][]byte)
@@ -1373,7 +1375,7 @@ func (tsw *TrieStateWriter) WriteAccountStorage(_ context.Context, address commo
 	}
 	m1[seckey] = struct{}{}
 	if len(v) > 0 {
-		m[seckey] = common.CopyBytes(v)
+		m[seckey] = v
 	} else {
 		m[seckey] = nil
 	}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 6cea32da2..8b78d5a7e 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,7 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/holiman/uint256"
 	"github.com/stretchr/testify/assert"
 
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
@@ -170,9 +171,9 @@ func TestCreate2Revive(t *testing.T) {
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
 	key2 := common.BigToHash(big.NewInt(2))
-	var check2 common.Hash
+	var check2 uint256.Int
 	st.GetState(create2address, &key2, &check2)
-	if check2 != common.HexToHash("0x42") {
+	if check2.Uint64() != 0x42 {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
 
@@ -205,14 +206,14 @@ func TestCreate2Revive(t *testing.T) {
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
 	key4 := common.BigToHash(big.NewInt(4))
-	var check4 common.Hash
+	var check4 uint256.Int
 	st.GetState(create2address, &key4, &check4)
-	if check4 != common.HexToHash("0x42") {
+	if check4.Uint64() != 0x42 {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
 	st.GetState(create2address, &key2, &check2)
-	if check2 != common.HexToHash("0x0") {
+	if !check2.IsZero() {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
 }
@@ -322,7 +323,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	var key0, correctValueX common.Hash
+	var key0 common.Hash
+	var correctValueX uint256.Int
 	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
@@ -351,7 +353,7 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	var valueX common.Hash
+	var valueX uint256.Int
 	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
@@ -457,7 +459,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	var key0, correctValueX common.Hash
+	var key0 common.Hash
+	var correctValueX uint256.Int
 	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
@@ -482,7 +485,7 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	var valueX common.Hash
+	var valueX uint256.Int
 	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
@@ -746,9 +749,10 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	var key0, check0 common.Hash
+	var key0 common.Hash
+	var check0 uint256.Int
 	st.GetState(contractAddress, &key0, &check0)
-	if check0 != common.HexToHash("0x0") {
+	if !check0.IsZero() {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
 }
@@ -760,12 +764,12 @@ func TestReproduceCrash(t *testing.T) {
 	// 1. Setting storageKey 1 to a non-zero value
 	// 2. Setting storageKey 2 to a non-zero value
 	// 3. Setting both storageKey1 and storageKey2 to zero values
-	value0 := common.Hash{}
+	value0 := uint256.NewInt()
 	contract := common.HexToAddress("0x71dd1027069078091B3ca48093B00E4735B20624")
 	storageKey1 := common.HexToHash("0x0e4c0e7175f9d22279a4f63ff74f7fa28b7a954a6454debaa62ce43dd9132541")
-	value1 := common.HexToHash("0x016345785d8a0000")
+	value1 := uint256.NewInt().SetUint64(0x016345785d8a0000)
 	storageKey2 := common.HexToHash("0x0e4c0e7175f9d22279a4f63ff74f7fa28b7a954a6454debaa62ce43dd9132542")
-	value2 := common.HexToHash("0x58c00a51")
+	value2 := uint256.NewInt().SetUint64(0x58c00a51)
 	db := ethdb.NewMemDatabase()
 	tds := state.NewTrieDbState(common.Hash{}, db, 0)
 
@@ -780,22 +784,22 @@ func TestReproduceCrash(t *testing.T) {
 	}
 	// Start the 2nd transaction
 	tds.StartNewBuffer()
-	intraBlockState.SetState(contract, storageKey1, value1)
+	intraBlockState.SetState(contract, &storageKey1, *value1)
 	if err := intraBlockState.FinalizeTx(ctx, tsw); err != nil {
 		t.Errorf("error finalising 1st tx: %v", err)
 	}
 	// Start the 3rd transaction
 	tds.StartNewBuffer()
 	intraBlockState.AddBalance(contract, big.NewInt(1000000000))
-	intraBlockState.SetState(contract, storageKey2, value2)
+	intraBlockState.SetState(contract, &storageKey2, *value2)
 	if err := intraBlockState.FinalizeTx(ctx, tsw); err != nil {
 		t.Errorf("error finalising 1st tx: %v", err)
 	}
 	// Start the 4th transaction - clearing both storage cells
 	tds.StartNewBuffer()
 	intraBlockState.SubBalance(contract, big.NewInt(1000000000))
-	intraBlockState.SetState(contract, storageKey1, value0)
-	intraBlockState.SetState(contract, storageKey2, value0)
+	intraBlockState.SetState(contract, &storageKey1, *value0)
+	intraBlockState.SetState(contract, &storageKey2, *value0)
 	if err := intraBlockState.FinalizeTx(ctx, tsw); err != nil {
 		t.Errorf("error finalising 1st tx: %v", err)
 	}
diff --git a/core/state/db_state_writer.go b/core/state/db_state_writer.go
index 1387936b1..3ef9e5e4d 100644
--- a/core/state/db_state_writer.go
+++ b/core/state/db_state_writer.go
@@ -6,6 +6,7 @@ import (
 	"fmt"
 
 	"github.com/VictoriaMetrics/fastcache"
+	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/changeset"
@@ -155,7 +156,7 @@ func (dsw *DbStateWriter) UpdateAccountCode(address common.Address, incarnation
 	return nil
 }
 
-func (dsw *DbStateWriter) WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (dsw *DbStateWriter) WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	// We delegate here first to let the changeSetWrite make its own decision on whether to proceed in case *original == *value
 	if err := dsw.csw.WriteAccountStorage(ctx, address, incarnation, key, original, value); err != nil {
 		return err
@@ -173,14 +174,14 @@ func (dsw *DbStateWriter) WriteAccountStorage(ctx context.Context, address commo
 	}
 	compositeKey := dbutils.GenerateCompositeStorageKey(addrHash, incarnation, seckey)
 
-	v := cleanUpTrailingZeroes(value[:])
+	v := value.Bytes()
 	if dsw.storageCache != nil {
 		dsw.storageCache.Set(compositeKey, v)
 	}
 	if len(v) == 0 {
 		return dsw.stateDb.Delete(dbutils.CurrentStateBucket, compositeKey)
 	}
-	return dsw.stateDb.Put(dbutils.CurrentStateBucket, compositeKey, common.CopyBytes(v))
+	return dsw.stateDb.Put(dbutils.CurrentStateBucket, compositeKey, v)
 }
 
 func (dsw *DbStateWriter) CreateContract(address common.Address) error {
diff --git a/core/state/history_test.go b/core/state/history_test.go
index a51e6e370..c15f273ad 100644
--- a/core/state/history_test.go
+++ b/core/state/history_test.go
@@ -11,6 +11,9 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/holiman/uint256"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/changeset"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
@@ -19,7 +22,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/trie"
-	"github.com/stretchr/testify/assert"
 )
 
 func TestMutation_DeleteTimestamp(t *testing.T) {
@@ -137,9 +139,9 @@ func TestMutationCommitThinHistory(t *testing.T) {
 			t.Fatal("incorrect history index")
 		}
 
-		resAccStorage := make(map[common.Hash]common.Hash)
+		resAccStorage := make(map[common.Hash]uint256.Int)
 		err = db.Walk(dbutils.CurrentStateBucket, dbutils.GenerateStoragePrefix(addrHash[:], acc.Incarnation), 8*(common.HashLength+8), func(k, v []byte) (b bool, e error) {
-			resAccStorage[common.BytesToHash(k[common.HashLength+8:])] = common.BytesToHash(v)
+			resAccStorage[common.BytesToHash(k[common.HashLength+8:])] = *uint256.NewInt().SetBytes(v)
 			return true, nil
 		})
 		if err != nil {
@@ -158,9 +160,9 @@ func TestMutationCommitThinHistory(t *testing.T) {
 				t.Fatal(err)
 			}
 
-			resultHash := common.BytesToHash(res)
-			if resultHash != v {
-				t.Fatalf("incorrect storage history for %x %x %x", addrHash.String(), v, resultHash)
+			result := uint256.NewInt().SetBytes(res)
+			if !v.Eq(result) {
+				t.Fatalf("incorrect storage history for %x %x %x", addrHash.String(), v, result)
 			}
 		}
 	}
@@ -211,7 +213,7 @@ func TestMutationCommitThinHistory(t *testing.T) {
 			if err1 != nil {
 				t.Fatal(err1)
 			}
-			value := common.Hash{uint8(10 + j)}
+			value := uint256.NewInt().SetUint64(uint64(10 + j))
 			if err2 := expectedChangeSet.Add(dbutils.GenerateCompositeStorageKey(addrHash, accHistory[i].Incarnation, keyHash), value.Bytes()); err2 != nil {
 				t.Fatal(err2)
 			}
@@ -227,13 +229,13 @@ func TestMutationCommitThinHistory(t *testing.T) {
 	}
 }
 
-func generateAccountsWithStorageAndHistory(t *testing.T, db ethdb.Database, numOfAccounts, numOfStateKeys int) ([]common.Hash, []*accounts.Account, []map[common.Hash]common.Hash, []*accounts.Account, []map[common.Hash]common.Hash) {
+func generateAccountsWithStorageAndHistory(t *testing.T, db ethdb.Database, numOfAccounts, numOfStateKeys int) ([]common.Hash, []*accounts.Account, []map[common.Hash]uint256.Int, []*accounts.Account, []map[common.Hash]uint256.Int) {
 	t.Helper()
 
 	accHistory := make([]*accounts.Account, numOfAccounts)
 	accState := make([]*accounts.Account, numOfAccounts)
-	accStateStorage := make([]map[common.Hash]common.Hash, numOfAccounts)
-	accHistoryStateStorage := make([]map[common.Hash]common.Hash, numOfAccounts)
+	accStateStorage := make([]map[common.Hash]uint256.Int, numOfAccounts)
+	accHistoryStateStorage := make([]map[common.Hash]uint256.Int, numOfAccounts)
 	addrs := make([]common.Address, numOfAccounts)
 	addrHashes := make([]common.Hash, numOfAccounts)
 	tds := NewTrieDbState(common.Hash{}, db, 1)
@@ -251,23 +253,23 @@ func generateAccountsWithStorageAndHistory(t *testing.T, db ethdb.Database, numO
 		accState[i].Nonce++
 		accState[i].Balance = *big.NewInt(200)
 
-		accStateStorage[i] = make(map[common.Hash]common.Hash)
-		accHistoryStateStorage[i] = make(map[common.Hash]common.Hash)
+		accStateStorage[i] = make(map[common.Hash]uint256.Int)
+		accHistoryStateStorage[i] = make(map[common.Hash]uint256.Int)
 		for j := 0; j < numOfStateKeys; j++ {
 			key := common.Hash{uint8(i*100 + j)}
 			keyHash, err := common.HashData(key.Bytes())
 			if err != nil {
 				t.Fatal(err)
 			}
-			newValue := common.Hash{uint8(j)}
-			if newValue != (common.Hash{}) {
+			newValue := uint256.NewInt().SetUint64(uint64(j))
+			if !newValue.IsZero() {
 				// Empty value is not considered to be present
-				accStateStorage[i][keyHash] = newValue
+				accStateStorage[i][keyHash] = *newValue
 			}
 
-			value := common.Hash{uint8(10 + j)}
-			accHistoryStateStorage[i][keyHash] = value
-			if err := blockWriter.WriteAccountStorage(ctx, addrs[i], accHistory[i].Incarnation, &key, &value, &newValue); err != nil {
+			value := uint256.NewInt().SetUint64(uint64(10 + j))
+			accHistoryStateStorage[i][keyHash] = *value
+			if err := blockWriter.WriteAccountStorage(ctx, addrs[i], accHistory[i].Incarnation, &key, value, newValue); err != nil {
 				t.Fatal(err)
 			}
 		}
@@ -309,7 +311,7 @@ func TestBoltDB_WalkAsOf1(t *testing.T) {
 	tds := NewTrieDbState(common.Hash{}, db, 1)
 	blockWriter := tds.DbStateWriter()
 	ctx := context.Background()
-	emptyVal := common.Hash{}
+	emptyVal := uint256.NewInt()
 
 	block2Expected := &changeset.ChangeSet{
 		Changes: make([]changeset.Change, 0),
@@ -330,15 +332,15 @@ func TestBoltDB_WalkAsOf1(t *testing.T) {
 		k := common.Hash{i}
 		keyHash, _ := common.HashData(k[:])
 		key := dbutils.GenerateCompositeStorageKey(addrHash, 1, keyHash)
-		val3 := common.BytesToHash([]byte("block 3 " + strconv.Itoa(int(i))))
-		val5 := common.BytesToHash([]byte("block 5 " + strconv.Itoa(int(i))))
-		val := common.BytesToHash([]byte("state   " + strconv.Itoa(int(i))))
+		val3 := uint256.NewInt().SetBytes([]byte("block 3 " + strconv.Itoa(int(i))))
+		val5 := uint256.NewInt().SetBytes([]byte("block 5 " + strconv.Itoa(int(i))))
+		val := uint256.NewInt().SetBytes([]byte("state   " + strconv.Itoa(int(i))))
 		if i <= 2 {
-			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, &val3, &val); err != nil {
+			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, val3, val); err != nil {
 				t.Fatal(err)
 			}
 		} else {
-			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, &val3, &val5); err != nil {
+			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, val3, val5); err != nil {
 				t.Fatal(err)
 			}
 		}
@@ -360,14 +362,14 @@ func TestBoltDB_WalkAsOf1(t *testing.T) {
 		k := common.Hash{i}
 		keyHash, _ := common.HashData(k[:])
 		key := dbutils.GenerateCompositeStorageKey(addrHash, 1, keyHash)
-		val5 := common.BytesToHash([]byte("block 5 " + strconv.Itoa(int(i))))
-		val := common.BytesToHash([]byte("state   " + strconv.Itoa(int(i))))
+		val5 := uint256.NewInt().SetBytes([]byte("block 5 " + strconv.Itoa(int(i))))
+		val := uint256.NewInt().SetBytes([]byte("state   " + strconv.Itoa(int(i))))
 		if i > 4 {
-			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, &val5, &emptyVal); err != nil {
+			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, val5, emptyVal); err != nil {
 				t.Fatal(err)
 			}
 		} else {
-			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, &val5, &val); err != nil {
+			if err := blockWriter.WriteAccountStorage(ctx, addr, 1, &k, val5, val); err != nil {
 				t.Fatal(err)
 			}
 		}
@@ -505,8 +507,8 @@ func TestUnwindTruncateHistory(t *testing.T) {
 			}
 			newAcc.Incarnation = FirstContractIncarnation
 		}
-		var oldValue common.Hash
-		var newValue common.Hash
+		var oldValue uint256.Int
+		var newValue uint256.Int
 		newValue[0] = 1
 		var location common.Hash
 		location.SetBytes(big.NewInt(int64(blockNumber)).Bytes())
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 6d63602fd..869f808f7 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -25,6 +25,9 @@ import (
 	"sort"
 	"sync"
 
+	"github.com/holiman/uint256"
+	"github.com/petar/GoLLRB/llrb"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
@@ -32,7 +35,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/trie"
-	"github.com/petar/GoLLRB/llrb"
 )
 
 type revision struct {
@@ -373,7 +375,7 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *uint256.Int) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
@@ -411,7 +413,7 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *uint256.Int) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
@@ -535,7 +537,7 @@ func (sdb *IntraBlockState) SetCode(addr common.Address, code []byte) {
 }
 
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) SetState(addr common.Address, key, value common.Hash) {
+func (sdb *IntraBlockState) SetState(addr common.Address, key *common.Hash, value uint256.Int) {
 	stateObject := sdb.GetOrNewStateObject(addr)
 	if stateObject != nil {
 		stateObject.SetState(key, value)
@@ -544,7 +546,7 @@ func (sdb *IntraBlockState) SetState(addr common.Address, key, value common.Hash
 
 // SetStorage replaces the entire storage for the specified account with given
 // storage. This function should only be used for debugging.
-func (sdb *IntraBlockState) SetStorage(addr common.Address, storage map[common.Hash]common.Hash) {
+func (sdb *IntraBlockState) SetStorage(addr common.Address, storage Storage) {
 	stateObject := sdb.GetOrNewStateObject(addr)
 	if stateObject != nil {
 		stateObject.SetStorage(storage)
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index 88233b4f9..1537d4c2b 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -29,6 +29,7 @@ import (
 	"testing"
 	"testing/quick"
 
+	"github.com/holiman/uint256"
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -52,7 +53,8 @@ func TestUpdateLeaks(t *testing.T) {
 		state.AddBalance(addr, big.NewInt(int64(11*i)))
 		state.SetNonce(addr, uint64(42*i))
 		if i%2 == 0 {
-			state.SetState(addr, common.BytesToHash([]byte{i, i, i}), common.BytesToHash([]byte{i, i, i, i}))
+			val := uint256.NewInt().SetBytes([]byte{i, i, i, i})
+			state.SetState(addr, &common.Hash{i, i, i}, *val)
 		}
 		if i%3 == 0 {
 			state.SetCode(addr, []byte{i, i, i, i, i})
@@ -96,8 +98,10 @@ func TestIntermediateLeaks(t *testing.T) {
 		state.SetBalance(addr, big.NewInt(int64(11*i)+int64(tweak)))
 		state.SetNonce(addr, uint64(42*i+tweak))
 		if i%2 == 0 {
-			state.SetState(addr, common.Hash{i, i, i, 0}, common.Hash{})
-			state.SetState(addr, common.Hash{i, i, i, tweak}, common.Hash{i, i, i, i, tweak})
+			val := uint256.NewInt()
+			state.SetState(addr, &common.Hash{i, i, i, 0}, *val)
+			val.SetBytes([]byte{i, i, i, i, tweak})
+			state.SetState(addr, &common.Hash{i, i, i, tweak}, *val)
 		}
 		if i%3 == 0 {
 			state.SetCode(addr, []byte{i, i, i, i, i, tweak})
@@ -247,10 +251,10 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 		{
 			name: "SetState",
 			fn: func(a testAction, s *IntraBlockState) {
-				var key, val common.Hash
+				var key common.Hash
 				binary.BigEndian.PutUint16(key[:], uint16(a.args[0]))
-				binary.BigEndian.PutUint16(val[:], uint16(a.args[1]))
-				s.SetState(addr, key, val)
+				val := uint256.NewInt().SetUint64(uint64(a.args[1]))
+				s.SetState(addr, &key, *val)
 			},
 			args: make([]int64, 2),
 		},
@@ -418,16 +422,22 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		checkeq("GetCodeSize", state.GetCodeSize(addr), checkstate.GetCodeSize(addr))
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
-			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				var out common.Hash
+			err = ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey common.Hash, value uint256.Int) bool {
+				var out uint256.Int
 				checkstate.GetState(addr, &key, &out)
 				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
-			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				var out common.Hash
+			if err != nil {
+				return err
+			}
+			err = checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey common.Hash, value uint256.Int) bool {
+				var out uint256.Int
 				state.GetState(addr, &key, &out)
 				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
+			if err != nil {
+				return err
+			}
 		}
 		if err != nil {
 			return err
diff --git a/core/state/journal.go b/core/state/journal.go
index 591c7610a..467672169 100644
--- a/core/state/journal.go
+++ b/core/state/journal.go
@@ -20,6 +20,8 @@ import (
 	"math/big"
 	"sync"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 )
 
@@ -120,8 +122,9 @@ type (
 		prev    uint64
 	}
 	storageChange struct {
-		account       *common.Address
-		key, prevalue common.Hash
+		account  *common.Address
+		key      common.Hash
+		prevalue uint256.Int
 	}
 	codeChange struct {
 		account  *common.Address
@@ -212,7 +215,7 @@ func (ch codeChange) dirtied() *common.Address {
 }
 
 func (ch storageChange) revert(s *IntraBlockState) {
-	s.getStateObject(*ch.account).setState(ch.key, ch.prevalue)
+	s.getStateObject(*ch.account).setState(&ch.key, ch.prevalue)
 }
 
 func (ch storageChange) dirtied() *common.Address {
diff --git a/core/state/plain_state_writer.go b/core/state/plain_state_writer.go
index 00e48f8cb..11332fee6 100644
--- a/core/state/plain_state_writer.go
+++ b/core/state/plain_state_writer.go
@@ -5,6 +5,7 @@ import (
 	"encoding/binary"
 
 	"github.com/VictoriaMetrics/fastcache"
+	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/changeset"
@@ -108,7 +109,7 @@ func (w *PlainStateWriter) DeleteAccount(ctx context.Context, address common.Add
 	return w.stateDb.Delete(dbutils.PlainStateBucket, address[:])
 }
 
-func (w *PlainStateWriter) WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (w *PlainStateWriter) WriteAccountStorage(ctx context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	if err := w.csw.WriteAccountStorage(ctx, address, incarnation, key, original, value); err != nil {
 		return err
 	}
@@ -117,14 +118,14 @@ func (w *PlainStateWriter) WriteAccountStorage(ctx context.Context, address comm
 	}
 	compositeKey := dbutils.PlainGenerateCompositeStorageKey(address, incarnation, *key)
 
-	v := cleanUpTrailingZeroes(value[:])
+	v := value.Bytes()
 	if w.storageCache != nil {
 		w.storageCache.Set(compositeKey, v)
 	}
 	if len(v) == 0 {
 		return w.stateDb.Delete(dbutils.PlainStateBucket, compositeKey)
 	}
-	return w.stateDb.Put(dbutils.PlainStateBucket, compositeKey, common.CopyBytes(v))
+	return w.stateDb.Put(dbutils.PlainStateBucket, compositeKey, v)
 }
 
 func (w *PlainStateWriter) CreateContract(address common.Address) error {
diff --git a/core/state/readonly.go b/core/state/readonly.go
index 8b3efc26a..05537a988 100644
--- a/core/state/readonly.go
+++ b/core/state/readonly.go
@@ -23,20 +23,23 @@ import (
 	"fmt"
 	"math/big"
 
+	"github.com/holiman/uint256"
+	"github.com/petar/GoLLRB/llrb"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ledgerwatch/turbo-geth/trie"
-	"github.com/petar/GoLLRB/llrb"
 )
 
 var _ StateReader = (*DbState)(nil)
 var _ StateWriter = (*DbState)(nil)
 
 type storageItem struct {
-	key, seckey, value common.Hash
+	key, seckey common.Hash
+	value       uint256.Int
 }
 
 func (a *storageItem) Less(b llrb.Item) bool {
@@ -67,7 +70,7 @@ func (dbs *DbState) GetBlockNr() uint64 {
 	return dbs.blockNr
 }
 
-func (dbs *DbState) ForEachStorage(addr common.Address, start []byte, cb func(key, seckey, value common.Hash) bool, maxResults int) error {
+func (dbs *DbState) ForEachStorage(addr common.Address, start []byte, cb func(key, seckey common.Hash, value uint256.Int) bool, maxResults int) error {
 	addrHash, err := common.HashData(addr[:])
 	if err != nil {
 		log.Error("Error on hashing", "err", err)
@@ -93,7 +96,7 @@ func (dbs *DbState) ForEachStorage(addr common.Address, start []byte, cb func(ke
 		t.AscendGreaterOrEqual(min, func(i llrb.Item) bool {
 			item := i.(*storageItem)
 			st.ReplaceOrInsert(item)
-			if item.value != emptyHash {
+			if !item.value.IsZero() {
 				copy(lastSecKey[:], item.seckey[:])
 				// Only count non-zero items
 				overrideCounter++
@@ -133,7 +136,7 @@ func (dbs *DbState) ForEachStorage(addr common.Address, start []byte, cb func(ke
 	var innerErr error
 	st.AscendGreaterOrEqual(min, func(i llrb.Item) bool {
 		item := i.(*storageItem)
-		if item.value != emptyHash {
+		if !item.value.IsZero() {
 			// Skip if value == 0
 			if item.key == emptyHash {
 				key, err := dbs.db.Get(dbutils.PreimagePrefix, item.seckey[:])
@@ -258,7 +261,7 @@ func (dbs *DbState) UpdateAccountCode(address common.Address, incarnation uint64
 	return nil
 }
 
-func (dbs *DbState) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (dbs *DbState) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	t, ok := dbs.storage[address]
 	if !ok {
 		t = llrb.New()
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 86857f8d7..0092d90e2 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -23,6 +23,8 @@ import (
 	"io"
 	"math/big"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
@@ -39,7 +41,7 @@ func (c Code) String() string {
 	return string(c) //strings.Join(Disassemble(c), " ")
 }
 
-type Storage map[common.Hash]common.Hash
+type Storage map[common.Hash]uint256.Int
 
 func (s Storage) String() (str string) {
 	for key, value := range s {
@@ -155,7 +157,7 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+func (so *stateObject) GetState(key *common.Hash, out *uint256.Int) {
 	value, dirty := so.dirtyStorage[*key]
 	if dirty {
 		*out = value
@@ -166,7 +168,7 @@ func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *uint256.Int) {
 	// If we have the original value cached, return that
 	{
 		value, cached := so.originStorage[*key]
@@ -196,17 +198,17 @@ func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 }
 
 // SetState updates a value in account storage.
-func (so *stateObject) SetState(key, value common.Hash) {
+func (so *stateObject) SetState(key *common.Hash, value uint256.Int) {
 	// If the new value is the same as old, don't set
-	var prev common.Hash
-	so.GetState(&key, &prev)
+	var prev uint256.Int
+	so.GetState(key, &prev)
 	if prev == value {
 		return
 	}
 	// New value is different, update and journal the change
 	so.db.journal.append(storageChange{
 		account:  &so.address,
-		key:      key,
+		key:      *key,
 		prevalue: prev,
 	})
 	so.setState(key, value)
@@ -218,7 +220,7 @@ func (so *stateObject) SetState(key, value common.Hash) {
 // lookup only happens in the fake state storage.
 //
 // Note this function should only be used for debugging purpose.
-func (so *stateObject) SetStorage(storage map[common.Hash]common.Hash) {
+func (so *stateObject) SetStorage(storage Storage) {
 	// Allocate fake storage if it's nil.
 	if so.fakeStorage == nil {
 		so.fakeStorage = make(Storage)
@@ -230,8 +232,8 @@ func (so *stateObject) SetStorage(storage map[common.Hash]common.Hash) {
 	// debugging and the `fake` storage won't be committed to database.
 }
 
-func (so *stateObject) setState(key, value common.Hash) {
-	so.dirtyStorage[key] = value
+func (so *stateObject) setState(key *common.Hash, value uint256.Int) {
+	so.dirtyStorage[*key] = value
 }
 
 // updateTrie writes cached storage modifications into the object's storage trie.
diff --git a/core/state/state_test.go b/core/state/state_test.go
index f591b9d98..341085b46 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -22,6 +22,7 @@ import (
 	"math/big"
 	"testing"
 
+	"github.com/holiman/uint256"
 	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -109,9 +110,9 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	address := common.HexToAddress("0x823140710bf13990e4500136726d8b55")
 	s.state.CreateAccount(address, true)
 	//value := common.FromHex("0x823140710bf13990e4500136726d8b55")
-	var value common.Hash
+	var value uint256.Int
 
-	s.state.SetState(address, common.Hash{}, value)
+	s.state.SetState(address, &common.Hash{}, value)
 
 	ctx := context.TODO()
 	err := s.state.FinalizeTx(ctx, s.tds.TrieStateWriter())
@@ -123,7 +124,7 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	c.Check(err, checker.IsNil)
 
 	s.state.GetCommittedState(address, &common.Hash{}, &value)
-	if value != (common.Hash{}) {
+	if !value.IsZero() {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -131,21 +132,21 @@ func (s *StateSuite) TestNull(c *checker.C) {
 func (s *StateSuite) TestSnapshot(c *checker.C) {
 	stateobjaddr := toAddr([]byte("aa"))
 	var storageaddr common.Hash
-	data1 := common.BytesToHash([]byte{42})
-	data2 := common.BytesToHash([]byte{43})
+	data1 := uint256.NewInt().SetUint64(42)
+	data2 := uint256.NewInt().SetUint64(43)
 
 	// snapshot the genesis state
 	genesis := s.state.Snapshot()
 
 	// set initial state object value
-	s.state.SetState(stateobjaddr, storageaddr, data1)
+	s.state.SetState(stateobjaddr, &storageaddr, *data1)
 	snapshot := s.state.Snapshot()
 
 	// set a new state object value, revert it and ensure correct content
-	s.state.SetState(stateobjaddr, storageaddr, data2)
+	s.state.SetState(stateobjaddr, &storageaddr, *data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	var value common.Hash
+	var value uint256.Int
 	s.state.GetState(stateobjaddr, &storageaddr, &value)
 	c.Assert(value, checker.DeepEquals, data1)
 	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
@@ -176,11 +177,11 @@ func TestSnapshot2(t *testing.T) {
 	stateobjaddr1 := toAddr([]byte("so1"))
 	var storageaddr common.Hash
 
-	data0 := common.BytesToHash([]byte{17})
-	data1 := common.BytesToHash([]byte{18})
+	data0 := uint256.NewInt().SetUint64(17)
+	data1 := uint256.NewInt().SetUint64(18)
 
-	state.SetState(stateobjaddr0, storageaddr, data0)
-	state.SetState(stateobjaddr1, storageaddr, data1)
+	state.SetState(stateobjaddr0, &storageaddr, *data0)
+	state.SetState(stateobjaddr1, &storageaddr, *data1)
 
 	// db, trie are already non-empty values
 	so0 := state.getStateObject(stateobjaddr0)
@@ -227,7 +228,7 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	var tmp common.Hash
+	var tmp uint256.Int
 	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
diff --git a/core/state/stateless.go b/core/state/stateless.go
index 8141ad084..7684a34d9 100644
--- a/core/state/stateless.go
+++ b/core/state/stateless.go
@@ -22,9 +22,10 @@ import (
 	"fmt"
 	"os"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/trie"
 )
@@ -212,13 +213,13 @@ func (s *Stateless) UpdateAccountCode(address common.Address, incarnation uint64
 
 // WriteAccountStorage is a part of the StateWriter interface
 // This implementation registeres the change of the account's storage in the internal double map `storageUpdates`
-func (s *Stateless) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key, original, value *common.Hash) error {
+func (s *Stateless) WriteAccountStorage(_ context.Context, address common.Address, incarnation uint64, key *common.Hash, original, value *uint256.Int) error {
 	addrHash, err := common.HashData(address[:])
 	if err != nil {
 		return err
 	}
 
-	v := bytes.TrimLeft(value[:], "\x00")
+	v := value.Bytes()
 	m, ok := s.storageUpdates[addrHash]
 	if !ok {
 		m = make(map[common.Hash][]byte)
diff --git a/core/state/util.go b/core/state/util.go
deleted file mode 100644
index be5ca31ed..000000000
--- a/core/state/util.go
+++ /dev/null
@@ -1,7 +0,0 @@
-package state
-
-import "bytes"
-
-func cleanUpTrailingZeroes(value []byte) []byte {
-	return bytes.TrimLeft(value[:], "\x00")
-}
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 4fff3c7b7..0c2cf7420 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -27,6 +27,7 @@ import (
 	"sync"
 
 	"github.com/ethereum/evmc/v7/bindings/go/evmc"
+	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types"
@@ -122,37 +123,35 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 }
 
 func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
-	var value common.Hash
+	var value uint256.Int
 	key := common.Hash(evmcKey)
 	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
-	return evmc.Hash(value)
+	return evmc.Hash(value.Bytes32())
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
-	value := common.Hash(evmcValue)
-	var oldValue common.Hash
+	value := uint256.NewInt().SetBytes(evmcValue[:])
+	var oldValue uint256.Int
 	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
-	if oldValue == value {
+	if oldValue.Eq(value) {
 		return evmc.StorageUnchanged
 	}
 
-	var current, original common.Hash
+	var current, original uint256.Int
 	host.env.IntraBlockState.GetState(addr, &key, &current)
 	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
-	host.env.IntraBlockState.SetState(addr, key, value)
+	host.env.IntraBlockState.SetState(addr, &key, *value)
 
 	hasNetStorageCostEIP := host.env.ChainConfig().IsConstantinople(host.env.BlockNumber) &&
 		!host.env.ChainConfig().IsPetersburg(host.env.BlockNumber)
 	if !hasNetStorageCostEIP {
-
-		zero := common.Hash{}
 		status = evmc.StorageModified
-		if oldValue == zero {
+		if oldValue.IsZero() {
 			return evmc.StorageAdded
-		} else if value == zero {
+		} else if value.IsZero() {
 			host.env.IntraBlockState.AddRefund(params.SstoreRefundGas)
 			return evmc.StorageDeleted
 		}
@@ -160,24 +159,24 @@ func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, ev
 	}
 
 	if original == current {
-		if original == (common.Hash{}) { // create slot (2.1.1)
+		if original.IsZero() { // create slot (2.1.1)
 			return evmc.StorageAdded
 		}
-		if value == (common.Hash{}) { // delete slot (2.1.2b)
+		if value.IsZero() { // delete slot (2.1.2b)
 			host.env.IntraBlockState.AddRefund(params.NetSstoreClearRefund)
 			return evmc.StorageDeleted
 		}
 		return evmc.StorageModified
 	}
-	if original != (common.Hash{}) {
-		if current == (common.Hash{}) { // recreate slot (2.2.1.1)
+	if !original.IsZero() {
+		if current.IsZero() { // recreate slot (2.2.1.1)
 			host.env.IntraBlockState.SubRefund(params.NetSstoreClearRefund)
-		} else if value == (common.Hash{}) { // delete slot (2.2.1.2)
+		} else if value.IsZero() { // delete slot (2.2.1.2)
 			host.env.IntraBlockState.AddRefund(params.NetSstoreClearRefund)
 		}
 	}
-	if original == value {
-		if original == (common.Hash{}) { // reset to original inexistent slot (2.2.2.1)
+	if original.Eq(value) {
+		if original.IsZero() { // reset to original inexistent slot (2.2.2.1)
 			host.env.IntraBlockState.AddRefund(params.NetSstoreResetClearRefund)
 		} else { // reset to original existing slot (2.2.2.2)
 			host.env.IntraBlockState.AddRefund(params.NetSstoreResetRefund)
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index 39c523d6a..f52029362 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -19,6 +19,8 @@ package vm
 import (
 	"errors"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/math"
 	"github.com/ledgerwatch/turbo-geth/params"
@@ -94,9 +96,9 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	y, x := stack.Back(1), stack.Back(0)
+	value, x := stack.Back(1), stack.Back(0)
 	key := common.Hash(x.Bytes32())
-	var current common.Hash
+	var current uint256.Int
 	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
@@ -109,9 +111,9 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 		// 2. From a non-zero value address to a zero-value address (DELETE)
 		// 3. From a non-zero to a non-zero                         (CHANGE)
 		switch {
-		case current == (common.Hash{}) && y.Sign() != 0: // 0 => non 0
+		case current.IsZero() && !value.IsZero(): // 0 => non 0
 			return params.SstoreSetGas, nil
-		case current != (common.Hash{}) && y.Sign() == 0: // non 0 => 0
+		case !current.IsZero() && value.IsZero(): // non 0 => 0
 			evm.IntraBlockState.AddRefund(params.SstoreRefundGas)
 			return params.SstoreClearGas, nil
 		default: // non 0 => non 0 (or 0 => 0)
@@ -132,30 +134,29 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	// 	  2.2.2. If original value equals new value (this storage slot is reset)
 	//       2.2.2.1. If original value is 0, add 19800 gas to refund counter.
 	// 	     2.2.2.2. Otherwise, add 4800 gas to refund counter.
-	value := common.Hash(y.Bytes32())
-	if current == value { // noop (1)
+	if current.Eq(value) { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	var original common.Hash
+	var original uint256.Int
 	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
-		if original == (common.Hash{}) { // create slot (2.1.1)
+		if original.IsZero() { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
 		}
-		if value == (common.Hash{}) { // delete slot (2.1.2b)
+		if value.IsZero() { // delete slot (2.1.2b)
 			evm.IntraBlockState.AddRefund(params.NetSstoreClearRefund)
 		}
 		return params.NetSstoreCleanGas, nil // write existing slot (2.1.2)
 	}
-	if original != (common.Hash{}) {
-		if current == (common.Hash{}) { // recreate slot (2.2.1.1)
+	if !original.IsZero() {
+		if current.IsZero() { // recreate slot (2.2.1.1)
 			evm.IntraBlockState.SubRefund(params.NetSstoreClearRefund)
-		} else if value == (common.Hash{}) { // delete slot (2.2.1.2)
+		} else if value.IsZero() { // delete slot (2.2.1.2)
 			evm.IntraBlockState.AddRefund(params.NetSstoreClearRefund)
 		}
 	}
-	if original == value {
-		if original == (common.Hash{}) { // reset to original inexistent slot (2.2.2.1)
+	if original.Eq(value) {
+		if original.IsZero() { // reset to original inexistent slot (2.2.2.1)
 			evm.IntraBlockState.AddRefund(params.NetSstoreResetClearRefund)
 		} else { // reset to original existing slot (2.2.2.2)
 			evm.IntraBlockState.AddRefund(params.NetSstoreResetRefund)
@@ -184,35 +185,34 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	y, x := stack.Back(1), stack.Back(0)
+	value, x := stack.Back(1), stack.Back(0)
 	key := common.Hash(x.Bytes32())
-	var current common.Hash
+	var current uint256.Int
 	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
-	value := common.Hash(y.Bytes32())
 
-	if current == value { // noop (1)
+	if current.Eq(value) { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	var original common.Hash
+	var original uint256.Int
 	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
-		if original == (common.Hash{}) { // create slot (2.1.1)
+		if original.IsZero() { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
 		}
-		if value == (common.Hash{}) { // delete slot (2.1.2b)
+		if value.IsZero() { // delete slot (2.1.2b)
 			evm.IntraBlockState.AddRefund(params.SstoreClearRefundEIP2200)
 		}
 		return params.SstoreCleanGasEIP2200, nil // write existing slot (2.1.2)
 	}
-	if original != (common.Hash{}) {
-		if current == (common.Hash{}) { // recreate slot (2.2.1.1)
+	if !original.IsZero() {
+		if current.IsZero() { // recreate slot (2.2.1.1)
 			evm.IntraBlockState.SubRefund(params.SstoreClearRefundEIP2200)
-		} else if value == (common.Hash{}) { // delete slot (2.2.1.2)
+		} else if value.IsZero() { // delete slot (2.2.1.2)
 			evm.IntraBlockState.AddRefund(params.SstoreClearRefundEIP2200)
 		}
 	}
-	if original == value {
-		if original == (common.Hash{}) { // reset to original inexistent slot (2.2.2.1)
+	if original.Eq(value) {
+		if original.IsZero() { // reset to original inexistent slot (2.2.2.1)
 			evm.IntraBlockState.AddRefund(params.SstoreInitRefundEIP2200)
 		} else { // reset to original existing slot (2.2.2.2)
 			evm.IntraBlockState.AddRefund(params.SstoreCleanRefundEIP2200)
diff --git a/core/vm/gas_table_test.go b/core/vm/gas_table_test.go
index 6531f32f1..4cf8464fb 100644
--- a/core/vm/gas_table_test.go
+++ b/core/vm/gas_table_test.go
@@ -22,6 +22,8 @@ import (
 	"math/big"
 	"testing"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/state"
@@ -87,7 +89,7 @@ func TestEIP2200(t *testing.T) {
 		s := state.New(tds)
 		s.CreateAccount(address, true)
 		s.SetCode(address, hexutil.MustDecode(tt.input))
-		s.SetState(address, common.Hash{}, common.BytesToHash([]byte{tt.original}))
+		s.SetState(address, &common.Hash{}, *uint256.NewInt().SetUint64(uint64(tt.original)))
 
 		s.CommitBlock(context.Background(), tds.DbStateWriter())
 
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 54d718729..a3569ac99 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -523,16 +523,15 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
 	interpreter.hasherBuf = loc.Bytes32()
-	var val common.Hash
-	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
-	loc.SetBytes(val.Bytes())
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, loc)
 	return nil, nil
 }
 
 func opSstore(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.pop()
 	val := callContext.stack.pop()
-	interpreter.evm.IntraBlockState.SetState(callContext.contract.Address(), common.Hash(loc.Bytes32()), common.Hash(val.Bytes32()))
+	interpreter.hasherBuf = loc.Bytes32()
+	interpreter.evm.IntraBlockState.SetState(callContext.contract.Address(), &interpreter.hasherBuf, val)
 	return nil, nil
 }
 
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 9dc28f6be..4d9506b69 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -19,6 +19,8 @@ package vm
 import (
 	"math/big"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 )
@@ -43,9 +45,9 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, *common.Hash, *common.Hash)
-	GetState(common.Address, *common.Hash, *common.Hash)
-	SetState(common.Address, common.Hash, common.Hash)
+	GetCommittedState(common.Address, *common.Hash, *uint256.Int)
+	GetState(common.Address, *common.Hash, *uint256.Int)
+	SetState(common.Address, *common.Hash, uint256.Int)
 
 	Suicide(common.Address) bool
 	HasSuicided(common.Address) bool
diff --git a/eth/api.go b/eth/api.go
index 4f9b52a92..bf37c39f1 100644
--- a/eth/api.go
+++ b/eth/api.go
@@ -28,6 +28,8 @@ import (
 	"strings"
 	"time"
 
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core"
@@ -419,9 +421,9 @@ func StorageRangeAt(dbstate *state.DbState, contractAddress common.Address, star
 	result := StorageRangeResult{Storage: StorageMap{}}
 	resultCount := 0
 
-	if err := dbstate.ForEachStorage(contractAddress, start, func(key, seckey, value common.Hash) bool {
+	if err := dbstate.ForEachStorage(contractAddress, start, func(key, seckey common.Hash, value uint256.Int) bool {
 		if resultCount < maxResult {
-			result.Storage[seckey] = StorageEntry{Key: &key, Value: value}
+			result.Storage[seckey] = StorageEntry{Key: &key, Value: value.Bytes32()}
 		} else {
 			result.NextKey = &seckey
 		}
diff --git a/eth/api_test.go b/eth/api_test.go
index 98212b9f0..5f56a3af6 100644
--- a/eth/api_test.go
+++ b/eth/api_test.go
@@ -18,6 +18,7 @@ package eth
 
 import (
 	"bytes"
+	"context"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -25,9 +26,9 @@ import (
 	"strconv"
 	"testing"
 
-	"context"
-
 	"github.com/davecgh/go-spew/spew"
+	"github.com/holiman/uint256"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/state"
 	"github.com/ledgerwatch/turbo-geth/crypto"
@@ -183,7 +184,8 @@ func TestStorageRangeAt(t *testing.T) {
 	tds.StartNewBuffer()
 
 	for _, entry := range storage {
-		statedb.SetState(addr, *entry.Key, entry.Value)
+		val := uint256.NewInt().SetBytes(entry.Value.Bytes())
+		statedb.SetState(addr, entry.Key, *val)
 	}
 	//we are working with contract, so it need codehash&incarnation
 	statedb.SetIncarnation(addr, state.FirstContractIncarnation)
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index 3113d9dce..9d18768cf 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -25,12 +25,14 @@ import (
 	"time"
 	"unsafe"
 
+	"github.com/holiman/uint256"
+	duktape "gopkg.in/olebedev/go-duktape.v3"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/vm"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/log"
-	duktape "gopkg.in/olebedev/go-duktape.v3"
 )
 
 // bigIntegerJS is the minified version of https://github.com/peterolson/BigInteger.js.
