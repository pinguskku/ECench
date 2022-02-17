commit 184e9ae9a81df2db6381e18d3daa035d913ae341
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun Aug 2 02:20:41 2015 +0200

    core, tests: reduced state copy by N calls
    
    Reduced the amount of state copied that are required by N calls by doing
    a balance check prior to any state modifications.

diff --git a/cmd/evm/main.go b/cmd/evm/main.go
index 7dd375b14..be6546c95 100644
--- a/cmd/evm/main.go
+++ b/cmd/evm/main.go
@@ -206,6 +206,9 @@ func (self *VMEnv) StructLogs() []vm.StructLog {
 func (self *VMEnv) AddLog(log *state.Log) {
 	self.state.AddLog(log)
 }
+func (self *VMEnv) CanTransfer(from vm.Account, balance *big.Int) bool {
+	return from.Balance().Cmp(balance) >= 0
+}
 func (self *VMEnv) Transfer(from, to vm.Account, amount *big.Int) error {
 	return vm.Transfer(from, to, amount)
 }
diff --git a/core/execution.go b/core/execution.go
index 699bad9a3..3a136515d 100644
--- a/core/execution.go
+++ b/core/execution.go
@@ -26,6 +26,7 @@ import (
 	"github.com/ethereum/go-ethereum/params"
 )
 
+// Execution is the execution environment for the given call or create action.
 type Execution struct {
 	env     vm.Environment
 	address *common.Address
@@ -35,12 +36,15 @@ type Execution struct {
 	Gas, price, value *big.Int
 }
 
+// NewExecution returns a new execution environment that handles all calling
+// and creation logic defined by the YP.
 func NewExecution(env vm.Environment, address *common.Address, input []byte, gas, gasPrice, value *big.Int) *Execution {
 	exe := &Execution{env: env, address: address, input: input, Gas: gas, price: gasPrice, value: value}
 	exe.evm = vm.NewVm(env)
 	return exe
 }
 
+// Call executes within the given context
 func (self *Execution) Call(codeAddr common.Address, caller vm.ContextRef) ([]byte, error) {
 	// Retrieve the executing code
 	code := self.env.State().GetCode(codeAddr)
@@ -48,6 +52,9 @@ func (self *Execution) Call(codeAddr common.Address, caller vm.ContextRef) ([]by
 	return self.exec(&codeAddr, code, caller)
 }
 
+// Create creates a new contract and runs the initialisation procedure of the
+// contract. This returns the returned code for the contract and is stored
+// elsewhere.
 func (self *Execution) Create(caller vm.ContextRef) (ret []byte, err error, account *state.StateObject) {
 	// Input must be nil for create
 	code := self.input
@@ -63,16 +70,24 @@ func (self *Execution) Create(caller vm.ContextRef) (ret []byte, err error, acco
 	return
 }
 
+// exec executes the given code and executes within the contextAddr context.
 func (self *Execution) exec(contextAddr *common.Address, code []byte, caller vm.ContextRef) (ret []byte, err error) {
 	env := self.env
 	evm := self.evm
+	// Depth check execution. Fail if we're trying to execute above the
+	// limit.
 	if env.Depth() > int(params.CallCreateDepth.Int64()) {
 		caller.ReturnGas(self.Gas, self.price)
 
 		return nil, vm.DepthError
 	}
 
-	vsnapshot := env.State().Copy()
+	if !env.CanTransfer(env.State().GetStateObject(caller.Address()), self.value) {
+		caller.ReturnGas(self.Gas, self.price)
+
+		return nil, ValueTransferErr("insufficient funds to transfer value. Req %v, has %v", self.value, env.State().GetBalance(caller.Address()))
+	}
+
 	var createAccount bool
 	if self.address == nil {
 		// Generate a new address
@@ -95,15 +110,7 @@ func (self *Execution) exec(contextAddr *common.Address, code []byte, caller vm.
 	} else {
 		to = env.State().GetOrNewStateObject(*self.address)
 	}
-
-	err = env.Transfer(from, to, self.value)
-	if err != nil {
-		env.State().Set(vsnapshot)
-
-		caller.ReturnGas(self.Gas, self.price)
-
-		return nil, ValueTransferErr("insufficient funds to transfer value. Req %v, has %v", self.value, from.Balance())
-	}
+	vm.Transfer(from, to, self.value)
 
 	context := vm.NewContext(caller, to, self.value, self.Gas, self.price)
 	context.SetCallCode(contextAddr, code)
diff --git a/core/vm/environment.go b/core/vm/environment.go
index 723924b6f..5a1bf3201 100644
--- a/core/vm/environment.go
+++ b/core/vm/environment.go
@@ -36,6 +36,7 @@ type Environment interface {
 	Time() uint64
 	Difficulty() *big.Int
 	GasLimit() *big.Int
+	CanTransfer(from Account, balance *big.Int) bool
 	Transfer(from, to Account, amount *big.Int) error
 	AddLog(*state.Log)
 	AddStructLog(StructLog)
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7793ff169..d7605e5a2 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -13,6 +13,7 @@
 //
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
 package vm
 
 import (
diff --git a/core/vm/jit.go b/core/vm/jit.go
index a77309223..c66630ae8 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -13,6 +13,7 @@
 //
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
 package vm
 
 import (
@@ -48,7 +49,7 @@ func SetJITCacheSize(size int) {
 	programs, _ = lru.New(size)
 }
 
-// GetProgram returns the program by id or nil when non-existant
+// GetProgram returns the program by id or nil when non-existent
 func GetProgram(id common.Hash) *Program {
 	if p, ok := programs.Get(id); ok {
 		return p.(*Program)
diff --git a/core/vm/jit_test.go b/core/vm/jit_test.go
index 70432d47b..5b3feea99 100644
--- a/core/vm/jit_test.go
+++ b/core/vm/jit_test.go
@@ -105,6 +105,9 @@ func (self *Env) AddLog(log *state.Log) {
 }
 func (self *Env) Depth() int     { return self.depth }
 func (self *Env) SetDepth(i int) { self.depth = i }
+func (self *Env) CanTransfer(from Account, balance *big.Int) bool {
+	return from.Balance().Cmp(balance) >= 0
+}
 func (self *Env) Transfer(from, to Account, amount *big.Int) error {
 	return nil
 }
diff --git a/core/vm/settings.go b/core/vm/settings.go
index 9e30d3add..b94efd9ab 100644
--- a/core/vm/settings.go
+++ b/core/vm/settings.go
@@ -13,6 +13,7 @@
 //
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
 package vm
 
 var (
diff --git a/core/vm_env.go b/core/vm_env.go
index c1a86d63e..719829543 100644
--- a/core/vm_env.go
+++ b/core/vm_env.go
@@ -69,6 +69,10 @@ func (self *VMEnv) GetHash(n uint64) common.Hash {
 func (self *VMEnv) AddLog(log *state.Log) {
 	self.state.AddLog(log)
 }
+func (self *VMEnv) CanTransfer(from vm.Account, balance *big.Int) bool {
+	return from.Balance().Cmp(balance) >= 0
+}
+
 func (self *VMEnv) Transfer(from, to vm.Account, amount *big.Int) error {
 	return vm.Transfer(from, to, amount)
 }
diff --git a/tests/util.go b/tests/util.go
index 6ee1a42db..3b94effc8 100644
--- a/tests/util.go
+++ b/tests/util.go
@@ -18,7 +18,6 @@ package tests
 
 import (
 	"bytes"
-	"errors"
 	"fmt"
 	"math/big"
 
@@ -192,18 +191,19 @@ func (self *Env) AddLog(log *state.Log) {
 }
 func (self *Env) Depth() int     { return self.depth }
 func (self *Env) SetDepth(i int) { self.depth = i }
-func (self *Env) Transfer(from, to vm.Account, amount *big.Int) error {
+func (self *Env) CanTransfer(from vm.Account, balance *big.Int) bool {
 	if self.skipTransfer {
-		// ugly hack
 		if self.initial {
 			self.initial = false
-			return nil
+			return true
 		}
+	}
 
-		if from.Balance().Cmp(amount) < 0 {
-			return errors.New("Insufficient balance in account")
-		}
+	return from.Balance().Cmp(balance) >= 0
+}
 
+func (self *Env) Transfer(from, to vm.Account, amount *big.Int) error {
+	if self.skipTransfer {
 		return nil
 	}
 	return vm.Transfer(from, to, amount)
