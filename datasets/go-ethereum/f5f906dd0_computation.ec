commit f5f906dd0d5c40dc2ca3436b79f5b65294de5ad0
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Jul 1 09:15:04 2021 +0200

    eth/tracers: improve tracing performance (#23016)
    
    Improves the performance of debug.traceTransaction

diff --git a/core/vm/gen_structlog.go b/core/vm/gen_structlog.go
index ac04afe8b..365f3b791 100644
--- a/core/vm/gen_structlog.go
+++ b/core/vm/gen_structlog.go
@@ -4,11 +4,11 @@ package vm
 
 import (
 	"encoding/json"
-	"math/big"
 
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/common/hexutil"
 	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/holiman/uint256"
 )
 
 var _ = (*structLogMarshaling)(nil)
@@ -22,8 +22,7 @@ func (s StructLog) MarshalJSON() ([]byte, error) {
 		GasCost       math.HexOrDecimal64         `json:"gasCost"`
 		Memory        hexutil.Bytes               `json:"memory"`
 		MemorySize    int                         `json:"memSize"`
-		Stack         []*math.HexOrDecimal256     `json:"stack"`
-		ReturnStack   []math.HexOrDecimal64       `json:"returnStack"`
+		Stack         []uint256.Int               `json:"stack"`
 		ReturnData    hexutil.Bytes               `json:"returnData"`
 		Storage       map[common.Hash]common.Hash `json:"-"`
 		Depth         int                         `json:"depth"`
@@ -39,12 +38,7 @@ func (s StructLog) MarshalJSON() ([]byte, error) {
 	enc.GasCost = math.HexOrDecimal64(s.GasCost)
 	enc.Memory = s.Memory
 	enc.MemorySize = s.MemorySize
-	if s.Stack != nil {
-		enc.Stack = make([]*math.HexOrDecimal256, len(s.Stack))
-		for k, v := range s.Stack {
-			enc.Stack[k] = (*math.HexOrDecimal256)(v)
-		}
-	}
+	enc.Stack = s.Stack
 	enc.ReturnData = s.ReturnData
 	enc.Storage = s.Storage
 	enc.Depth = s.Depth
@@ -64,7 +58,7 @@ func (s *StructLog) UnmarshalJSON(input []byte) error {
 		GasCost       *math.HexOrDecimal64        `json:"gasCost"`
 		Memory        *hexutil.Bytes              `json:"memory"`
 		MemorySize    *int                        `json:"memSize"`
-		Stack         []*math.HexOrDecimal256     `json:"stack"`
+		Stack         []uint256.Int               `json:"stack"`
 		ReturnData    *hexutil.Bytes              `json:"returnData"`
 		Storage       map[common.Hash]common.Hash `json:"-"`
 		Depth         *int                        `json:"depth"`
@@ -94,10 +88,7 @@ func (s *StructLog) UnmarshalJSON(input []byte) error {
 		s.MemorySize = *dec.MemorySize
 	}
 	if dec.Stack != nil {
-		s.Stack = make([]*big.Int, len(dec.Stack))
-		for k, v := range dec.Stack {
-			s.Stack[k] = (*big.Int)(v)
-		}
+		s.Stack = dec.Stack
 	}
 	if dec.ReturnData != nil {
 		s.ReturnData = *dec.ReturnData
diff --git a/core/vm/logger.go b/core/vm/logger.go
index 9ccaafc77..900a5e585 100644
--- a/core/vm/logger.go
+++ b/core/vm/logger.go
@@ -29,6 +29,7 @@ import (
 	"github.com/ethereum/go-ethereum/common/math"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/holiman/uint256"
 )
 
 // Storage represents a contract's storage.
@@ -66,7 +67,7 @@ type StructLog struct {
 	GasCost       uint64                      `json:"gasCost"`
 	Memory        []byte                      `json:"memory"`
 	MemorySize    int                         `json:"memSize"`
-	Stack         []*big.Int                  `json:"stack"`
+	Stack         []uint256.Int               `json:"stack"`
 	ReturnData    []byte                      `json:"returnData"`
 	Storage       map[common.Hash]common.Hash `json:"-"`
 	Depth         int                         `json:"depth"`
@@ -76,7 +77,6 @@ type StructLog struct {
 
 // overrides for gencodec
 type structLogMarshaling struct {
-	Stack       []*math.HexOrDecimal256
 	Gas         math.HexOrDecimal64
 	GasCost     math.HexOrDecimal64
 	Memory      hexutil.Bytes
@@ -135,6 +135,14 @@ func NewStructLogger(cfg *LogConfig) *StructLogger {
 	return logger
 }
 
+// Reset clears the data held by the logger.
+func (l *StructLogger) Reset() {
+	l.storage = make(map[common.Address]Storage)
+	l.output = make([]byte, 0)
+	l.logs = l.logs[:0]
+	l.err = nil
+}
+
 // CaptureStart implements the Tracer interface to initialize the tracing operation.
 func (l *StructLogger) CaptureStart(env *EVM, from common.Address, to common.Address, create bool, input []byte, gas uint64, value *big.Int) {
 }
@@ -157,16 +165,16 @@ func (l *StructLogger) CaptureState(env *EVM, pc uint64, op OpCode, gas, cost ui
 		copy(mem, memory.Data())
 	}
 	// Copy a snapshot of the current stack state to a new buffer
-	var stck []*big.Int
+	var stck []uint256.Int
 	if !l.cfg.DisableStack {
-		stck = make([]*big.Int, len(stack.Data()))
+		stck = make([]uint256.Int, len(stack.Data()))
 		for i, item := range stack.Data() {
-			stck[i] = new(big.Int).Set(item.ToBig())
+			stck[i] = item
 		}
 	}
 	// Copy a snapshot of the current storage to a new container
 	var storage Storage
-	if !l.cfg.DisableStorage {
+	if !l.cfg.DisableStorage && (op == SLOAD || op == SSTORE) {
 		// initialise new changed values storage container for this contract
 		// if not present.
 		if l.storage[contract.Address()] == nil {
@@ -179,16 +187,16 @@ func (l *StructLogger) CaptureState(env *EVM, pc uint64, op OpCode, gas, cost ui
 				value   = env.StateDB.GetState(contract.Address(), address)
 			)
 			l.storage[contract.Address()][address] = value
-		}
-		// capture SSTORE opcodes and record the written entry in the local storage.
-		if op == SSTORE && stack.len() >= 2 {
+			storage = l.storage[contract.Address()].Copy()
+		} else if op == SSTORE && stack.len() >= 2 {
+			// capture SSTORE opcodes and record the written entry in the local storage.
 			var (
 				value   = common.Hash(stack.data[stack.len()-2].Bytes32())
 				address = common.Hash(stack.data[stack.len()-1].Bytes32())
 			)
 			l.storage[contract.Address()][address] = value
+			storage = l.storage[contract.Address()].Copy()
 		}
-		storage = l.storage[contract.Address()].Copy()
 	}
 	var rdata []byte
 	if !l.cfg.DisableReturnData {
@@ -238,7 +246,7 @@ func WriteTrace(writer io.Writer, logs []StructLog) {
 		if len(log.Stack) > 0 {
 			fmt.Fprintln(writer, "Stack:")
 			for i := len(log.Stack) - 1; i >= 0; i-- {
-				fmt.Fprintf(writer, "%08d  %x\n", len(log.Stack)-i-1, math.PaddedBigBytes(log.Stack[i], 32))
+				fmt.Fprintf(writer, "%08d  %s\n", len(log.Stack)-i-1, log.Stack[i].Hex())
 			}
 		}
 		if len(log.Memory) > 0 {
@@ -314,7 +322,7 @@ func (t *mdLogger) CaptureState(env *EVM, pc uint64, op OpCode, gas, cost uint64
 		// format stack
 		var a []string
 		for _, elem := range stack.data {
-			a = append(a, fmt.Sprintf("%v", elem.String()))
+			a = append(a, elem.Hex())
 		}
 		b := fmt.Sprintf("[%v]", strings.Join(a, ","))
 		fmt.Fprintf(t.out, "%10v |", b)
diff --git a/core/vm/logger_json.go b/core/vm/logger_json.go
index 93878b980..5210f479f 100644
--- a/core/vm/logger_json.go
+++ b/core/vm/logger_json.go
@@ -57,7 +57,6 @@ func (l *JSONLogger) CaptureState(env *EVM, pc uint64, op OpCode, gas, cost uint
 		Gas:           gas,
 		GasCost:       cost,
 		MemorySize:    memory.Len(),
-		Storage:       nil,
 		Depth:         depth,
 		RefundCounter: env.StateDB.GetRefund(),
 		Err:           err,
@@ -66,12 +65,7 @@ func (l *JSONLogger) CaptureState(env *EVM, pc uint64, op OpCode, gas, cost uint
 		log.Memory = memory.Data()
 	}
 	if !l.cfg.DisableStack {
-		//TODO(@holiman) improve this
-		logstack := make([]*big.Int, len(stack.Data()))
-		for i, item := range stack.Data() {
-			logstack[i] = item.ToBig()
-		}
-		log.Stack = logstack
+		log.Stack = stack.data
 	}
 	if !l.cfg.DisableReturnData {
 		log.ReturnData = rData
diff --git a/eth/tracers/tracers_test.go b/eth/tracers/tracers_test.go
index 4f4f7c1ed..8fbbf154b 100644
--- a/eth/tracers/tracers_test.go
+++ b/eth/tracers/tracers_test.go
@@ -300,3 +300,81 @@ func jsonEqual(x, y interface{}) bool {
 	}
 	return reflect.DeepEqual(xTrace, yTrace)
 }
+
+func BenchmarkTransactionTrace(b *testing.B) {
+	key, _ := crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
+	from := crypto.PubkeyToAddress(key.PublicKey)
+	gas := uint64(1000000) // 1M gas
+	to := common.HexToAddress("0x00000000000000000000000000000000deadbeef")
+	signer := types.LatestSignerForChainID(big.NewInt(1337))
+	tx, err := types.SignNewTx(key, signer,
+		&types.LegacyTx{
+			Nonce:    1,
+			GasPrice: big.NewInt(500),
+			Gas:      gas,
+			To:       &to,
+		})
+	if err != nil {
+		b.Fatal(err)
+	}
+	txContext := vm.TxContext{
+		Origin:   from,
+		GasPrice: tx.GasPrice(),
+	}
+	context := vm.BlockContext{
+		CanTransfer: core.CanTransfer,
+		Transfer:    core.Transfer,
+		Coinbase:    common.Address{},
+		BlockNumber: new(big.Int).SetUint64(uint64(5)),
+		Time:        new(big.Int).SetUint64(uint64(5)),
+		Difficulty:  big.NewInt(0xffffffff),
+		GasLimit:    gas,
+	}
+	alloc := core.GenesisAlloc{}
+	// The code pushes 'deadbeef' into memory, then the other params, and calls CREATE2, then returns
+	// the address
+	loop := []byte{
+		byte(vm.JUMPDEST), //  [ count ]
+		byte(vm.PUSH1), 0, // jumpdestination
+		byte(vm.JUMP),
+	}
+	alloc[common.HexToAddress("0x00000000000000000000000000000000deadbeef")] = core.GenesisAccount{
+		Nonce:   1,
+		Code:    loop,
+		Balance: big.NewInt(1),
+	}
+	alloc[from] = core.GenesisAccount{
+		Nonce:   1,
+		Code:    []byte{},
+		Balance: big.NewInt(500000000000000),
+	}
+	_, statedb := tests.MakePreState(rawdb.NewMemoryDatabase(), alloc, false)
+	// Create the tracer, the EVM environment and run it
+	tracer := vm.NewStructLogger(&vm.LogConfig{
+		Debug: false,
+		//DisableStorage: true,
+		//DisableMemory: true,
+		//DisableReturnData: true,
+	})
+	evm := vm.NewEVM(context, txContext, statedb, params.AllEthashProtocolChanges, vm.Config{Debug: true, Tracer: tracer})
+	msg, err := tx.AsMessage(signer, nil)
+	if err != nil {
+		b.Fatalf("failed to prepare transaction for tracing: %v", err)
+	}
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		snap := statedb.Snapshot()
+		st := core.NewStateTransition(evm, msg, new(core.GasPool).AddGas(tx.Gas()))
+		_, err = st.TransitionDb()
+		if err != nil {
+			b.Fatal(err)
+		}
+		statedb.RevertToSnapshot(snap)
+		if have, want := len(tracer.StructLogs()), 244752; have != want {
+			b.Fatalf("trace wrong, want %d steps, have %d", want, have)
+		}
+		tracer.Reset()
+	}
+}
diff --git a/internal/ethapi/api.go b/internal/ethapi/api.go
index f9c5f0445..becfc2f5b 100644
--- a/internal/ethapi/api.go
+++ b/internal/ethapi/api.go
@@ -1117,7 +1117,7 @@ func FormatLogs(logs []vm.StructLog) []StructLogRes {
 		if trace.Stack != nil {
 			stack := make([]string, len(trace.Stack))
 			for i, stackValue := range trace.Stack {
-				stack[i] = fmt.Sprintf("%x", math.PaddedBigBytes(stackValue, 32))
+				stack[i] = stackValue.Hex()
 			}
 			formatted[index].Stack = &stack
 		}
