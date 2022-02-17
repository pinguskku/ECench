commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // ncommit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEqualsoop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // ncommit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, corroop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
ectValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEcommit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}achStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // n
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
oop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // ncommit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}oop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}

 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
commit df2857542057295bef7dffe7a6fabeca3215ddc5
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Sun May 24 18:43:54 2020 +0200

    Use pointers to hashes in Get(Commited)State to reduce memory allocation (#573)
    
    * Produce less garbage in GetState
    
    * Still playing with mem allocation in GetCommittedState
    
    * Pass key by pointer in GetState as well
    
    * linter
    
    * Avoid a memory allocation in opSload

diff --git a/accounts/abi/bind/backends/simulated.go b/accounts/abi/bind/backends/simulated.go
index c280e4703..f16bc774c 100644
--- a/accounts/abi/bind/backends/simulated.go
+++ b/accounts/abi/bind/backends/simulated.go
@@ -235,7 +235,8 @@ func (b *SimulatedBackend) StorageAt(ctx context.Context, contract common.Addres
 	if err != nil {
 		return nil, err
 	}
-	val := statedb.GetState(contract, key)
+	var val common.Hash
+	statedb.GetState(contract, &key, &val)
 	return val[:], nil
 }
 
diff --git a/common/types.go b/common/types.go
index 453ae1bf0..7a84c0e3a 100644
--- a/common/types.go
+++ b/common/types.go
@@ -120,6 +120,13 @@ func (h *Hash) SetBytes(b []byte) {
 	copy(h[HashLength-len(b):], b)
 }
 
+// Clear sets the hash to zero.
+func (h *Hash) Clear() {
+	for i := 0; i < HashLength; i++ {
+		h[i] = 0
+	}
+}
+
 // Generate implements testing/quick.Generator.
 func (h Hash) Generate(rand *rand.Rand, size int) reflect.Value {
 	m := rand.Intn(len(h))
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 4951f50ce..2b6599f31 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -27,6 +27,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // So we can deterministically seed different blockchains
@@ -2761,17 +2762,26 @@ func TestDeleteRecreateSlots(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then slot 1 and 2 are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 	// Also, 3 and 4 should be set
-	if got, exp := statedb.GetState(aa, common.HexToHash("03")), common.HexToHash("03"); got != exp {
+	key3 := common.HexToHash("03")
+	statedb.GetState(aa, &key3, &got)
+	if exp := common.HexToHash("03"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("04")), common.HexToHash("04"); got != exp {
+	key4 := common.HexToHash("04")
+	statedb.GetState(aa, &key4, &got)
+	if exp := common.HexToHash("04"); got != exp {
 		t.Fatalf("got %x exp %x", got, exp)
 	}
 }
@@ -2849,10 +2859,15 @@ func TestDeleteRecreateAccount(t *testing.T) {
 	statedb, _, _ := chain.State()
 
 	// If all is correct, then both slots are zero
-	if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+	key1 := common.HexToHash("01")
+	var got common.Hash
+	statedb.GetState(aa, &key1, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
-	if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+	key2 := common.HexToHash("02")
+	statedb.GetState(aa, &key2, &got)
+	if exp := (common.Hash{}); got != exp {
 		t.Errorf("got %x exp %x", got, exp)
 	}
 }
@@ -3037,10 +3052,15 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 		}
 		statedb, _, _ := chain.State()
 		// If all is correct, then slot 1 and 2 are zero
-		if got, exp := statedb.GetState(aa, common.HexToHash("01")), (common.Hash{}); got != exp {
+		key1 := common.HexToHash("01")
+		var got common.Hash
+		statedb.GetState(aa, &key1, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
-		if got, exp := statedb.GetState(aa, common.HexToHash("02")), (common.Hash{}); got != exp {
+		key2 := common.HexToHash("02")
+		statedb.GetState(aa, &key2, &got)
+		if exp := (common.Hash{}); got != exp {
 			t.Errorf("block %d, got %x exp %x", blockNum, got, exp)
 		}
 		exp := expectations[i]
@@ -3049,7 +3069,10 @@ func TestDeleteRecreateSlotsAcrossManyBlocks(t *testing.T) {
 				t.Fatalf("block %d, expected %v to exist, it did not", blockNum, aa)
 			}
 			for slot, val := range exp.values {
-				if gotValue, expValue := statedb.GetState(aa, asHash(slot)), asHash(val); gotValue != expValue {
+				key := asHash(slot)
+				var gotValue common.Hash
+				statedb.GetState(aa, &key, &gotValue)
+				if expValue := asHash(val); gotValue != expValue {
 					t.Fatalf("block %d, slot %d, got %x exp %x", blockNum, slot, gotValue, expValue)
 				}
 			}
diff --git a/core/state/database_test.go b/core/state/database_test.go
index 103af5da9..6cea32da2 100644
--- a/core/state/database_test.go
+++ b/core/state/database_test.go
@@ -24,6 +24,8 @@ import (
 	"testing"
 
 	"github.com/davecgh/go-spew/spew"
+	"github.com/stretchr/testify/assert"
+
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi/bind/backends"
 	"github.com/ledgerwatch/turbo-geth/common"
@@ -39,7 +41,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 	"github.com/ledgerwatch/turbo-geth/params"
-	"github.com/stretchr/testify/assert"
 )
 
 // Create revival problem
@@ -168,7 +169,9 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [2], because it is the block number 2
-	check2 := st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	key2 := common.BigToHash(big.NewInt(2))
+	var check2 common.Hash
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 2, got: %x", check2)
 	}
@@ -201,12 +204,14 @@ func TestCreate2Revive(t *testing.T) {
 		t.Error("expected create2address to exist at the block 2", create2address.String())
 	}
 	// We expect number 0x42 in the position [4], because it is the block number 4
-	check4 := st.GetState(create2address, common.BigToHash(big.NewInt(4)))
+	key4 := common.BigToHash(big.NewInt(4))
+	var check4 common.Hash
+	st.GetState(create2address, &key4, &check4)
 	if check4 != common.HexToHash("0x42") {
 		t.Errorf("expected 0x42 in position 4, got: %x", check4)
 	}
 	// We expect number 0x0 in the position [2], because it is the block number 4
-	check2 = st.GetState(create2address, common.BigToHash(big.NewInt(2)))
+	st.GetState(create2address, &key2, &check2)
 	if check2 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x0 in position 2, got: %x", check2)
 	}
@@ -317,7 +322,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	// BLOCKS 2 + 3
 	if _, err = blockchain.InsertChain(context.Background(), types.Blocks{blocks[1], blocks[2]}); err != nil {
@@ -345,7 +351,8 @@ func TestReorgOverSelfDestruct(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -450,7 +457,8 @@ func TestReorgOverStateChange(t *testing.T) {
 	}
 
 	// Remember value of field "x" (storage item 0) after the first block, to check after rewinding
-	correctValueX := st.GetState(contractAddress, common.Hash{})
+	var key0, correctValueX common.Hash
+	st.GetState(contractAddress, &key0, &correctValueX)
 
 	fmt.Println("Insert block 2")
 	// BLOCK 2
@@ -474,7 +482,8 @@ func TestReorgOverStateChange(t *testing.T) {
 		t.Fatal(err)
 	}
 	st, _, _ = blockchain.State()
-	valueX := st.GetState(contractAddress, common.Hash{})
+	var valueX common.Hash
+	st.GetState(contractAddress, &key0, &valueX)
 	if valueX != correctValueX {
 		t.Fatalf("storage value has changed after reorg: %x, expected %x", valueX, correctValueX)
 	}
@@ -737,7 +746,8 @@ func TestCreateOnExistingStorage(t *testing.T) {
 		t.Error("expected contractAddress to exist at the block 1", contractAddress.String())
 	}
 
-	check0 := st.GetState(contractAddress, common.BigToHash(big.NewInt(0)))
+	var key0, check0 common.Hash
+	st.GetState(contractAddress, &key0, &check0)
 	if check0 != common.HexToHash("0x0") {
 		t.Errorf("expected 0x00 in position 0, got: %x", check0)
 	}
diff --git a/core/state/intra_block_state.go b/core/state/intra_block_state.go
index 0b77b7e63..6d63602fd 100644
--- a/core/state/intra_block_state.go
+++ b/core/state/intra_block_state.go
@@ -373,15 +373,16 @@ func (sdb *IntraBlockState) GetCodeHash(addr common.Address) common.Hash {
 
 // GetState retrieves a value from the given account's storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetState(hash)
+		stateObject.GetState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 // GetProof returns the Merkle proof for a given account
@@ -410,15 +411,16 @@ func (sdb *IntraBlockState) GetStorageProof(a common.Address, key common.Hash) (
 
 // GetCommittedState retrieves a value from the given account's committed storage trie.
 // DESCRIBED: docs/programmers_guide/guide.md#address---identifier-of-an-account
-func (sdb *IntraBlockState) GetCommittedState(addr common.Address, hash common.Hash) common.Hash {
+func (sdb *IntraBlockState) GetCommittedState(addr common.Address, key *common.Hash, value *common.Hash) {
 	sdb.Lock()
 	defer sdb.Unlock()
 
 	stateObject := sdb.getStateObject(addr)
 	if stateObject != nil {
-		return stateObject.GetCommittedState(hash)
+		stateObject.GetCommittedState(key, value)
+	} else {
+		value.Clear()
 	}
-	return common.Hash{}
 }
 
 func (sdb *IntraBlockState) HasSuicided(addr common.Address) bool {
diff --git a/core/state/intra_block_state_test.go b/core/state/intra_block_state_test.go
index bde2c059c..88233b4f9 100644
--- a/core/state/intra_block_state_test.go
+++ b/core/state/intra_block_state_test.go
@@ -18,6 +18,7 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"encoding/binary"
 	"fmt"
 	"math"
@@ -28,13 +29,10 @@ import (
 	"testing"
 	"testing/quick"
 
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-
-	"context"
-
 	check "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
@@ -421,10 +419,14 @@ func (test *snapshotTest) checkEqual(state, checkstate *IntraBlockState, ds, che
 		// Check storage.
 		if obj := state.getStateObject(addr); obj != nil {
 			ds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", checkstate.GetState(addr, key), value)
+				var out common.Hash
+				checkstate.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 			checkds.ForEachStorage(addr, []byte{} /*startKey*/, func(key, seckey, value common.Hash) bool {
-				return checkeq("GetState("+key.Hex()+")", state.GetState(addr, key), value)
+				var out common.Hash
+				state.GetState(addr, &key, &out)
+				return checkeq("GetState("+key.Hex()+")", out, value)
 			}, 1000)
 		}
 		if err != nil {
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 4067a3a90..86857f8d7 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -155,46 +155,51 @@ func (so *stateObject) touch() {
 }
 
 // GetState returns a value from account storage.
-func (so *stateObject) GetState(key common.Hash) common.Hash {
-	value, dirty := so.dirtyStorage[key]
+func (so *stateObject) GetState(key *common.Hash, out *common.Hash) {
+	value, dirty := so.dirtyStorage[*key]
 	if dirty {
-		return value
+		*out = value
+		return
 	}
 	// Otherwise return the entry's original value
-	return so.GetCommittedState(key)
+	so.GetCommittedState(key, out)
 }
 
 // GetCommittedState retrieves a value from the committed account storage trie.
-func (so *stateObject) GetCommittedState(key common.Hash) common.Hash {
+func (so *stateObject) GetCommittedState(key *common.Hash, out *common.Hash) {
 	// If we have the original value cached, return that
 	{
-		value, cached := so.originStorage[key]
+		value, cached := so.originStorage[*key]
 		if cached {
-			return value
+			*out = value
+			return
 		}
 	}
 	if so.created {
-		return common.Hash{}
+		out.Clear()
+		return
 	}
 	// Load from DB in case it is missing.
-	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), &key)
+	enc, err := so.db.stateReader.ReadAccountStorage(so.address, so.data.GetIncarnation(), key)
 	if err != nil {
 		so.setError(err)
-		return common.Hash{}
+		out.Clear()
+		return
 	}
-	var value common.Hash
 	if enc != nil {
-		value.SetBytes(enc)
+		out.SetBytes(enc)
+	} else {
+		out.Clear()
 	}
-	so.originStorage[key] = value
-	so.blockOriginStorage[key] = value
-	return value
+	so.originStorage[*key] = *out
+	so.blockOriginStorage[*key] = *out
 }
 
 // SetState updates a value in account storage.
 func (so *stateObject) SetState(key, value common.Hash) {
 	// If the new value is the same as old, don't set
-	prev := so.GetState(key)
+	var prev common.Hash
+	so.GetState(&key, &prev)
 	if prev == value {
 		return
 	}
diff --git a/core/state/state_test.go b/core/state/state_test.go
index 8aefb2fba..f591b9d98 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -18,16 +18,16 @@ package state
 
 import (
 	"bytes"
+	"context"
 	"math/big"
 	"testing"
 
-	"context"
+	checker "gopkg.in/check.v1"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/core/types/accounts"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
-	checker "gopkg.in/check.v1"
 )
 
 type StateSuite struct {
@@ -122,7 +122,8 @@ func (s *StateSuite) TestNull(c *checker.C) {
 	err = s.state.CommitBlock(ctx, s.tds.DbStateWriter())
 	c.Check(err, checker.IsNil)
 
-	if value := s.state.GetCommittedState(address, common.Hash{}); value != (common.Hash{}) {
+	s.state.GetCommittedState(address, &common.Hash{}, &value)
+	if value != (common.Hash{}) {
 		c.Errorf("expected empty hash. got %x", value)
 	}
 }
@@ -144,13 +145,18 @@ func (s *StateSuite) TestSnapshot(c *checker.C) {
 	s.state.SetState(stateobjaddr, storageaddr, data2)
 	s.state.RevertToSnapshot(snapshot)
 
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, data1)
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	var value common.Hash
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, data1)
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 
 	// revert up to the genesis state and ensure correct content
 	s.state.RevertToSnapshot(genesis)
-	c.Assert(s.state.GetState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
-	c.Assert(s.state.GetCommittedState(stateobjaddr, storageaddr), checker.DeepEquals, common.Hash{})
+	s.state.GetState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
+	s.state.GetCommittedState(stateobjaddr, &storageaddr, &value)
+	c.Assert(value, checker.DeepEquals, common.Hash{})
 }
 
 func (s *StateSuite) TestSnapshotEmpty(c *checker.C) {
@@ -221,7 +227,8 @@ func TestSnapshot2(t *testing.T) {
 
 	so0Restored := state.getStateObject(stateobjaddr0)
 	// Update lazily-loaded values before comparing.
-	so0Restored.GetState(storageaddr)
+	var tmp common.Hash
+	so0Restored.GetState(&storageaddr, &tmp)
 	so0Restored.Code()
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/vm/evmc.go b/core/vm/evmc.go
index 619aaa01a..4fff3c7b7 100644
--- a/core/vm/evmc.go
+++ b/core/vm/evmc.go
@@ -121,21 +121,26 @@ func (host *hostContext) AccountExists(evmcAddr evmc.Address) bool {
 	return false
 }
 
-func (host *hostContext) GetStorage(addr evmc.Address, key evmc.Hash) evmc.Hash {
-	return evmc.Hash(host.env.IntraBlockState.GetState(common.Address(addr), common.Hash(key)))
+func (host *hostContext) GetStorage(addr evmc.Address, evmcKey evmc.Hash) evmc.Hash {
+	var value common.Hash
+	key := common.Hash(evmcKey)
+	host.env.IntraBlockState.GetState(common.Address(addr), &key, &value)
+	return evmc.Hash(value)
 }
 
 func (host *hostContext) SetStorage(evmcAddr evmc.Address, evmcKey evmc.Hash, evmcValue evmc.Hash) (status evmc.StorageStatus) {
 	addr := common.Address(evmcAddr)
 	key := common.Hash(evmcKey)
 	value := common.Hash(evmcValue)
-	oldValue := host.env.IntraBlockState.GetState(addr, key)
+	var oldValue common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &oldValue)
 	if oldValue == value {
 		return evmc.StorageUnchanged
 	}
 
-	current := host.env.IntraBlockState.GetState(addr, key)
-	original := host.env.IntraBlockState.GetCommittedState(addr, key)
+	var current, original common.Hash
+	host.env.IntraBlockState.GetState(addr, &key, &current)
+	host.env.IntraBlockState.GetCommittedState(addr, &key, &original)
 
 	host.env.IntraBlockState.SetState(addr, key, value)
 
diff --git a/core/vm/gas_table.go b/core/vm/gas_table.go
index d13055826..39c523d6a 100644
--- a/core/vm/gas_table.go
+++ b/core/vm/gas_table.go
@@ -94,10 +94,10 @@ var (
 )
 
 func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySize uint64) (uint64, error) {
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 
 	// The legacy gas metering only takes into consideration the current state
 	// Legacy rules should be applied if we are in Petersburg (removal of EIP-1283)
@@ -136,7 +136,8 @@ func gasSStore(evm *EVM, contract *Contract, stack *Stack, mem *Memory, memorySi
 	if current == value { // noop (1)
 		return params.NetSstoreNoopGas, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.NetSstoreInitGas, nil
@@ -183,16 +184,17 @@ func gasSStoreEIP2200(evm *EVM, contract *Contract, stack *Stack, mem *Memory, m
 		return 0, errors.New("not enough gas for reentrancy sentry")
 	}
 	// Gas sentry honoured, do the actual gas calculation based on the stored value
-	var (
-		y, x    = stack.Back(1), stack.Back(0)
-		current = evm.IntraBlockState.GetState(contract.Address(), common.Hash(x.Bytes32()))
-	)
+	y, x := stack.Back(1), stack.Back(0)
+	key := common.Hash(x.Bytes32())
+	var current common.Hash
+	evm.IntraBlockState.GetState(contract.Address(), &key, &current)
 	value := common.Hash(y.Bytes32())
 
 	if current == value { // noop (1)
 		return params.SstoreNoopGasEIP2200, nil
 	}
-	original := evm.IntraBlockState.GetCommittedState(contract.Address(), common.Hash(x.Bytes32()))
+	var original common.Hash
+	evm.IntraBlockState.GetCommittedState(contract.Address(), &key, &original)
 	if original == current {
 		if original == (common.Hash{}) { // create slot (2.1.1)
 			return params.SstoreInitGasEIP2200, nil
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index b8f73763c..54d718729 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -522,8 +522,9 @@ func opMstore8(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([
 
 func opSload(pc *uint64, interpreter *EVMInterpreter, callContext *callCtx) ([]byte, error) {
 	loc := callContext.stack.peek()
-	hash := common.Hash(loc.Bytes32())
-	val := interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), hash)
+	interpreter.hasherBuf = loc.Bytes32()
+	var val common.Hash
+	interpreter.evm.IntraBlockState.GetState(callContext.contract.Address(), &interpreter.hasherBuf, &val)
 	loc.SetBytes(val.Bytes())
 	return nil, nil
 }
diff --git a/core/vm/interface.go b/core/vm/interface.go
index 78164a71b..9dc28f6be 100644
--- a/core/vm/interface.go
+++ b/core/vm/interface.go
@@ -43,8 +43,8 @@ type IntraBlockState interface {
 	SubRefund(uint64)
 	GetRefund() uint64
 
-	GetCommittedState(common.Address, common.Hash) common.Hash
-	GetState(common.Address, common.Hash) common.Hash
+	GetCommittedState(common.Address, *common.Hash, *common.Hash)
+	GetState(common.Address, *common.Hash, *common.Hash)
 	SetState(common.Address, common.Hash, common.Hash)
 
 	Suicide(common.Address) bool
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 9a8b1b409..41df4c18a 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -84,7 +84,7 @@ type EVMInterpreter struct {
 	jt *JumpTable // EVM instruction table
 
 	hasher    keccakState // Keccak256 hasher instance shared across opcodes
-	hasherBuf common.Hash // Keccak256 hasher result array shared aross opcodes
+	hasherBuf common.Hash // Keccak256 hasher result array shared across opcodes
 
 	readOnly   bool   // Whether to throw on stateful modifications
 	returnData []byte // Last CALL's return data for subsequent reuse
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index d7fff5ba1..3113d9dce 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -223,7 +223,9 @@ func (dw *dbWrapper) pushObject(vm *duktape.Context) {
 		hash := popSlice(ctx)
 		addr := popSlice(ctx)
 
-		state := dw.db.GetState(common.BytesToAddress(addr), common.BytesToHash(hash))
+		key := common.BytesToHash(hash)
+		var state common.Hash
+		dw.db.GetState(common.BytesToAddress(addr), &key, &state)
 
 		ptr := ctx.PushFixedBuffer(len(state))
 		copy(makeSlice(ptr, uint(len(state))), state[:])
diff --git a/graphql/graphql.go b/graphql/graphql.go
index 2b9427284..be37f5c1f 100644
--- a/graphql/graphql.go
+++ b/graphql/graphql.go
@@ -22,7 +22,7 @@ import (
 	"errors"
 	"time"
 
-	"github.com/ledgerwatch/turbo-geth"
+	ethereum "github.com/ledgerwatch/turbo-geth"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/rawdb"
@@ -85,7 +85,9 @@ func (a *Account) Storage(ctx context.Context, args struct{ Slot common.Hash })
 	if err != nil {
 		return common.Hash{}, err
 	}
-	return state.GetState(a.address, args.Slot), nil
+	var val common.Hash
+	state.GetState(a.address, &args.Slot, &val)
+	return val, nil
 }
 
 // Log represents an individual log message. All arguments are mandatory.
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index efa458d2a..97f1d58b5 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -25,6 +25,8 @@ import (
 	"time"
 
 	"github.com/davecgh/go-spew/spew"
+	bip39 "github.com/tyler-smith/go-bip39"
+
 	"github.com/ledgerwatch/turbo-geth/accounts"
 	"github.com/ledgerwatch/turbo-geth/accounts/abi"
 	"github.com/ledgerwatch/turbo-geth/accounts/keystore"
@@ -44,7 +46,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/rpc"
-	bip39 "github.com/tyler-smith/go-bip39"
 )
 
 // PublicEthereumAPI provides an API to access Ethereum related information.
@@ -659,7 +660,9 @@ func (s *PublicBlockChainAPI) GetStorageAt(ctx context.Context, address common.A
 	if state == nil || err != nil {
 		return nil, err
 	}
-	res := state.GetState(address, common.HexToHash(key))
+	keyHash := common.HexToHash(key)
+	var res common.Hash
+	state.GetState(address, &keyHash, &res)
 	return res[:], state.Error()
 }
 
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index ba90612e0..25ebcdf75 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -106,9 +106,12 @@ func (t *VMTest) Run(vmconfig vm.Config, blockNr uint64) error {
 	if gasRemaining != uint64(*t.json.GasRemaining) {
 		return fmt.Errorf("remaining gas %v, want %v", gasRemaining, *t.json.GasRemaining)
 	}
+	var haveV common.Hash
 	for addr, account := range t.json.Post {
 		for k, wantV := range account.Storage {
-			if haveV := state.GetState(addr, k); haveV != wantV {
+			key := k
+			state.GetState(addr, &key, &haveV)
+			if haveV != wantV {
 				return fmt.Errorf("wrong storage value at %x:\n  got  %x\n  want %x", k, haveV, wantV)
 			}
 		}
