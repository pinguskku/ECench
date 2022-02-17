commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
commit 00b45acb9e104f3229a7f2f3be88686d4bcb5706
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Sep 1 21:35:30 2015 +0200

    core: improve block gas tracking

diff --git a/core/block_processor.go b/core/block_processor.go
index 99d27fa71..1238fda7b 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -56,6 +56,18 @@ type BlockProcessor struct {
 	eventMux *event.TypeMux
 }
 
+// TODO: type GasPool big.Int
+//
+// GasPool is implemented by state.StateObject. This is a historical
+// coincidence. Gas tracking should move out of StateObject.
+
+// GasPool tracks the amount of gas available during
+// execution of the transactions in a block.
+type GasPool interface {
+	AddGas(gas, price *big.Int)
+	SubGas(gas, price *big.Int) error
+}
+
 func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManager, eventMux *event.TypeMux) *BlockProcessor {
 	sm := &BlockProcessor{
 		chainDb:  db,
@@ -64,16 +76,15 @@ func NewBlockProcessor(db common.Database, pow pow.PoW, chainManager *ChainManag
 		bc:       chainManager,
 		eventMux: eventMux,
 	}
-
 	return sm
 }
 
 func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block *types.Block, transientProcess bool) (receipts types.Receipts, err error) {
-	coinbase := statedb.GetOrNewStateObject(block.Coinbase())
-	coinbase.SetGasLimit(block.GasLimit())
+	gp := statedb.GetOrNewStateObject(block.Coinbase())
+	gp.SetGasLimit(block.GasLimit())
 
 	// Process the transactions on to parent state
-	receipts, err = sm.ApplyTransactions(coinbase, statedb, block, block.Transactions(), transientProcess)
+	receipts, err = sm.ApplyTransactions(gp, statedb, block, block.Transactions(), transientProcess)
 	if err != nil {
 		return nil, err
 	}
@@ -81,9 +92,8 @@ func (sm *BlockProcessor) TransitionState(statedb *state.StateDB, parent, block
 	return receipts, nil
 }
 
-func (self *BlockProcessor) ApplyTransaction(coinbase *state.StateObject, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
-	cb := statedb.GetStateObject(coinbase.Address())
-	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, cb)
+func (self *BlockProcessor) ApplyTransaction(gp GasPool, statedb *state.StateDB, header *types.Header, tx *types.Transaction, usedGas *big.Int, transientProcess bool) (*types.Receipt, *big.Int, error) {
+	_, gas, err := ApplyMessage(NewEnv(statedb, self.bc, tx, header), tx, gp)
 	if err != nil {
 		return nil, nil, err
 	}
@@ -118,7 +128,7 @@ func (self *BlockProcessor) ChainManager() *ChainManager {
 	return self.bc
 }
 
-func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
+func (self *BlockProcessor) ApplyTransactions(gp GasPool, statedb *state.StateDB, block *types.Block, txs types.Transactions, transientProcess bool) (types.Receipts, error) {
 	var (
 		receipts      types.Receipts
 		totalUsedGas  = big.NewInt(0)
@@ -130,7 +140,7 @@ func (self *BlockProcessor) ApplyTransactions(coinbase *state.StateObject, state
 	for i, tx := range txs {
 		statedb.StartRecord(tx.Hash(), block.Hash(), i)
 
-		receipt, txGas, err := self.ApplyTransaction(coinbase, statedb, header, tx, totalUsedGas, transientProcess)
+		receipt, txGas, err := self.ApplyTransaction(gp, statedb, header, tx, totalUsedGas, transientProcess)
 		if err != nil {
 			return nil, err
 		}
diff --git a/core/state_transition.go b/core/state_transition.go
index a5d4fc19b..6ff7fa1ff 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -45,7 +45,7 @@ import (
  * 6) Derive new state root
  */
 type StateTransition struct {
-	coinbase      common.Address
+	gp            GasPool
 	msg           Message
 	gas, gasPrice *big.Int
 	initialGas    *big.Int
@@ -53,8 +53,6 @@ type StateTransition struct {
 	data          []byte
 	state         *state.StateDB
 
-	cb, rec, sen *state.StateObject
-
 	env vm.Environment
 }
 
@@ -96,13 +94,13 @@ func IntrinsicGas(data []byte) *big.Int {
 	return igas
 }
 
-func ApplyMessage(env vm.Environment, msg Message, coinbase *state.StateObject) ([]byte, *big.Int, error) {
-	return NewStateTransition(env, msg, coinbase).transitionState()
+func ApplyMessage(env vm.Environment, msg Message, gp GasPool) ([]byte, *big.Int, error) {
+	return NewStateTransition(env, msg, gp).transitionState()
 }
 
-func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateObject) *StateTransition {
+func NewStateTransition(env vm.Environment, msg Message, gp GasPool) *StateTransition {
 	return &StateTransition{
-		coinbase:   coinbase.Address(),
+		gp:         gp,
 		env:        env,
 		msg:        msg,
 		gas:        new(big.Int),
@@ -111,13 +109,9 @@ func NewStateTransition(env vm.Environment, msg Message, coinbase *state.StateOb
 		value:      msg.Value(),
 		data:       msg.Data(),
 		state:      env.State(),
-		cb:         coinbase,
 	}
 }
 
-func (self *StateTransition) Coinbase() *state.StateObject {
-	return self.state.GetOrNewStateObject(self.coinbase)
-}
 func (self *StateTransition) From() (*state.StateObject, error) {
 	f, err := self.msg.From()
 	if err != nil {
@@ -160,7 +154,7 @@ func (self *StateTransition) BuyGas() error {
 	if sender.Balance().Cmp(mgval) < 0 {
 		return fmt.Errorf("insufficient ETH for gas (%x). Req %v, has %v", sender.Address().Bytes()[:4], mgval, sender.Balance())
 	}
-	if err = self.Coinbase().SubGas(mgas, self.gasPrice); err != nil {
+	if err = self.gp.SubGas(mgas, self.gasPrice); err != nil {
 		return err
 	}
 	self.AddGas(mgas)
@@ -241,13 +235,12 @@ func (self *StateTransition) transitionState() (ret []byte, usedGas *big.Int, er
 	}
 
 	self.refundGas()
-	self.state.AddBalance(self.coinbase, new(big.Int).Mul(self.gasUsed(), self.gasPrice))
+	self.state.AddBalance(self.env.Coinbase(), new(big.Int).Mul(self.gasUsed(), self.gasPrice))
 
 	return ret, self.gasUsed(), err
 }
 
 func (self *StateTransition) refundGas() {
-	coinbase := self.Coinbase()
 	sender, _ := self.From() // err already checked
 	// Return remaining gas
 	remaining := new(big.Int).Mul(self.gas, self.gasPrice)
@@ -258,7 +251,7 @@ func (self *StateTransition) refundGas() {
 	self.gas.Add(self.gas, refund)
 	self.state.AddBalance(sender.Address(), refund.Mul(refund, self.gasPrice))
 
-	coinbase.AddGas(self.gas, self.gasPrice)
+	self.gp.AddGas(self.gas, self.gasPrice)
 }
 
 func (self *StateTransition) gasUsed() *big.Int {
