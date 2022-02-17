commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
commit f189e7e045e2b2ada768c8eda5693ef0835d210f
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon May 4 11:54:24 2020 +0300

    tests: cleanup snapshot generator goroutine leak
    
    # Conflicts:
    #       cmd/evm/staterunner.go
    #       eth/tracers/tracers_test.go
    #       tests/state_test.go
    #       tests/state_test_util.go
    #       tests/vm_test_util.go

diff --git a/tests/state_test_util.go b/tests/state_test_util.go
index 9ab61d4d2..e32bee383 100644
--- a/tests/state_test_util.go
+++ b/tests/state_test_util.go
@@ -144,41 +144,42 @@ func (t *StateTest) Subtests() []StateSubtest {
 	return sub
 }
 
-// Run executes a specific subtest.
-func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.Config) (*state.IntraBlockState, ethdb.Getter, uint64, common.Hash, error) {
-	statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
+// Run executes a specific subtest and verifies the post-state and logs
+func (t *StateTest) Run(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, error) {
+	snaps, statedb, root, err := t.RunNoVerify(subtest, vmconfig, snapshotter)
 	if err != nil {
-		return statedb, err
+		return snaps, statedb, err
 	}
 	config, ok := Forks[subtest.Fork]
 	// N.B: We need to do this in a two-step process, because the first Commit takes care
 	// of suicides, and we need to touch the coinbase _after_ it has potentially suicided.
-	if !ok {
-		return statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
+	if root != common.Hash(post.Root) {
+		return snaps, statedb, fmt.Errorf("post state root mismatch: got %x, want %x", root, post.Root)
 	}
-		return nil, nil, 0, common.Hash{}, UnsupportedForkError{subtest.Fork}
-		return statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
+	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
+		return snaps, statedb, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	block, _, _, _ := t.genesis(config).ToBlock(nil, false /* history */)
-	readBlockNr := block.Number().Uint64()
-	writeBlockNr := readBlockNr + 1
-	ctx = config.WithEIPsFlags(ctx, big.NewInt(int64(writeBlockNr)))
+	return snaps, statedb, nil
+}
 
-	db := ethdb.NewMemDatabase()
-	statedb, tds, err := MakePreState(context.Background(), db, t.json.Pre, readBlockNr)
+// RunNoVerify runs a specific subtest and returns the statedb and post-state root
+func (t *StateTest) RunNoVerify(subtest StateSubtest, vmconfig vm.Config, snapshotter bool) (*snapshot.Tree, *state.StateDB, common.Hash, error) {
+	config, eips, err := getVMConfig(subtest.Fork)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, fmt.Errorf("error in MakePreState: %v", err)
+		return nil, nil, common.Hash{}, UnsupportedForkError{subtest.Fork}
 	}
-	tds.StartNewBuffer()
+	vmconfig.ExtraEips = eips
+	block := t.genesis(config).ToBlock(nil)
+	snaps, statedb := MakePreState(rawdb.NewMemoryDatabase(), t.json.Pre, snapshotter)
 
 	post := t.json.Post[subtest.Fork][subtest.Index]
 	msg, err := t.json.Tx.toMessage(post)
 	if err != nil {
-		return nil, nil, 0, common.Hash{}, err
+		return nil, nil, common.Hash{}, err
 	}
-	evmCtx := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
-	evmCtx.GetHash = vmTestBlockHash
-	evm := vm.NewEVM(evmCtx, statedb, config, vmconfig)
+	context := core.NewEVMContext(msg, block.Header(), nil, &t.json.Env.Coinbase)
+	context.GetHash = vmTestBlockHash
+	evm := vm.NewEVM(context, statedb, config, vmconfig)
 
 	gaspool := new(core.GasPool)
 	gaspool.AddGas(block.GasLimit())
@@ -224,7 +225,7 @@ func (t *StateTest) Run(ctx context.Context, subtest StateSubtest, vmconfig vm.C
 	if logs := rlpHash(statedb.Logs()); logs != common.Hash(post.Logs) {
 		return statedb, db, readBlockNr + 1, common.Hash{}, fmt.Errorf("post state logs hash mismatch: got %x, want %x", logs, post.Logs)
 	}
-	return statedb, db, readBlockNr + 1, root, nil
+	return snaps, statedb, root, nil
 }
 
 func (t *StateTest) gasLimit(subtest StateSubtest) uint64 {
