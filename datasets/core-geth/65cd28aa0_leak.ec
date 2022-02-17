commit 65cd28aa0eca876b6a3e3b702889d3bde4386e9d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak

diff --git a/cmd/evm/staterunner.go b/cmd/evm/staterunner.go
index 52c1eca71..6f9e47cf5 100644
--- a/cmd/evm/staterunner.go
+++ b/cmd/evm/staterunner.go
@@ -96,7 +96,7 @@ func stateTestCmd(ctx *cli.Context) error {
 		for _, st := range test.Subtests() {
 			// Run the test and aggregate the result
 			result := &StatetestResult{Name: key, Fork: st.Fork, Pass: true}
-			state, err := test.Run(st, cfg, false)
+			_, state, err := test.Run(st, cfg, false)
 			// print state root for evmlab tracing
 			if ctx.GlobalBool(MachineFlag.Name) && state != nil {
 				fmt.Fprintf(os.Stderr, "{\"stateRoot\": \"%x\"}\n", state.IntermediateRoot(false))
diff --git a/eth/tracers/tracers_test.go b/eth/tracers/tracers_test.go
index 7227e20eb..cd625be0f 100644
--- a/eth/tracers/tracers_test.go
+++ b/eth/tracers/tracers_test.go
@@ -168,7 +168,7 @@ func TestPrestateTracerCreate2(t *testing.T) {
 		Code:    []byte{},
 		Balance: big.NewInt(500000000000000),
 	}
-	statedb := tests.MakePreState(rawdb.NewMemoryDatabase(), alloc, false)
+	_, statedb := tests.MakePreState(rawdb.NewMemoryDatabase(), alloc, false)
 
 	// Create the tracer, the EVM environment and run it
 	tracer, err := New("prestateTracer")
@@ -242,7 +242,7 @@ func TestCallTracer(t *testing.T) {
 				GasLimit:    uint64(test.Context.GasLimit),
 				GasPrice:    tx.GasPrice(),
 			}
-			statedb := tests.MakePreState(rawdb.NewMemoryDatabase(), test.Genesis.Alloc, false)
+			_, statedb := tests.MakePreState(rawdb.NewMemoryDatabase(), test.Genesis.Alloc, false)
 
 			// Create the tracer, the EVM environment and run it
 			tracer, err := New("callTracer")
diff --git a/tests/state_test.go b/tests/state_test.go
index c0a90b3a4..413990147 100644
--- a/tests/state_test.go
+++ b/tests/state_test.go
@@ -66,13 +66,16 @@ func TestState(t *testing.T) {
 
 				t.Run(key+"/trie", func(t *testing.T) {
 					withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
-						_, err := test.Run(subtest, vmconfig, false)
+						_, _, err := test.Run(subtest, vmconfig, false)
 						return st.checkFailure(t, name+"/trie", err)
 					})
 				})
 				t.Run(key+"/snap", func(t *testing.T) {
 					withTrace(t, test.gasLimit(subtest), func(vmconfig vm.Config) error {
-						_, err := test.Run(subtest, vmconfig, true)
+						snaps, statedb, err := test.Run(subtest, vmconfig, true)
+						if _, err := snaps.Journal(statedb.IntermediateRoot(false)); err != nil {
+							return err
+						}
 						return st.checkFailure(t, name+"/snap", err)
 					})
 				})
diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 4cea4d39e..a8d6fac51 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -147,37 +147,37 @@ func (t *StateTest) Subtests() []StateSubtest {
 }
 
 // Run executes a specific subtest and verifies the post-state and logs
-func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*state.StateDB, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
 	if root != common.Hash(post.Root) {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, nil
+	return snaps, statedb, nil
 }
 
 // RunNoVerify runs a specific subtest and returns the statedb and post-state root
-func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*state.StateDB, common.Hash, error) {
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
 	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
 	vmconfig.ExtraEips = eips
 	block := t.genesis(config).ToBlock(nil)
-	statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
 	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
 	context.GetHash = vmTestBlockHash
@@ -199,14 +199,14 @@ func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapsh
 	statedb.AddBalance(block.Coinbase(), new(big.Int))
 	// And _now_ get the state root
 	root := statedb.IntermediateRoot(config.IsEIP158(block.Number()))
-	return statedb, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
 	return t.json.Tx.GasLimit[t.json.Post[subtest.Fork][subtest.Index].Indexes.Gas]
 }
 
-func MakePreState(db ethdb.Database, accounts core.GenesisAlloc, snapshotter bool) *state.StateDB {
+func MakePreState(db ethdb.Database, accounts core.GenesisAlloc, snapshotter bool) (*snapshot.Tree, *state.StateDB) {
 	sdb := state.NewDatabase(db)
 	statedb, _ := state.New(common.Hash{}, sdb, nil)
 	for addr, a := range accounts {
@@ -225,7 +225,7 @@ func MakePreState(db ethdb.Database, accounts core.GenesisAlloc, snapshotter boo
 		snaps = snapshot.New(db, sdb.TrieDB(), 1, root, false)
 	}
 	statedb, _ = state.New(root, sdb, snaps)
-	return statedb
+	return snaps, statedb
 }
 
 func (t *StateTest) genesis(config *params.ChainConfig) *core.Genesis {
diff --git a/tests/vm_test_util.go b/tests/vm_test_util.go
index 9acbe59f4..ad124b7b2 100644
--- a/tests/vm_test_util.go
+++ b/tests/vm_test_util.go
@@ -79,7 +79,15 @@ type vmExecMarshaling struct {
 }
 
 func (t *VMTest) Run(vmconfig vm.Config, snapshotter bool) error {
-	statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
+	if snapshotter {
+		preRoot := statedb.IntermediateRoot(false)
+		defer func() {
+			if _, err := snaps.Journal(preRoot); err != nil {
+				panic(err)
+			}
+		}()
+	}
 	ret, gasRemaining, err := t.exec(statedb, vmconfig)
 
 	if t.json.GasRemaining == nil {
