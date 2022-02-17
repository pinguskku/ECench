commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
commit a816e756625d39fc9b544f97dfa218d885996f33
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 23 10:39:53 2017 +0200

    core/vm: improved push instructions
    
    Improved push instructions by removing unnecessary big int allocations
    and by making it int instead of big.Int

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index fa4dbe428..c0ac911ac 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -706,10 +706,23 @@ func makeLog(size int) executionFunc {
 }
 
 // make push instruction function
-func makePush(size uint64, bsize *big.Int) executionFunc {
+func makePush(size uint64, pushByteSize int) executionFunc {
 	return func(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-		byts := getData(contract.Code, evm.interpreter.intPool.get().SetUint64(*pc+1), bsize)
-		stack.push(new(big.Int).SetBytes(byts))
+		codeLen := len(contract.Code)
+
+		startMin := codeLen
+		if int(*pc+1) < startMin {
+			startMin = int(*pc + 1)
+		}
+
+		endMin := codeLen
+		if startMin+pushByteSize < endMin {
+			endMin = startMin + pushByteSize
+		}
+
+		integer := evm.interpreter.intPool.get()
+		stack.push(integer.SetBytes(common.RightPadBytes(contract.Code[startMin:endMin], pushByteSize)))
+
 		*pc += size
 		return nil, nil
 	}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index a6d49166e..0034eacb7 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -421,193 +421,193 @@ func NewFrontierInstructionSet() [256]operation {
 			valid:         true,
 		},
 		PUSH1: {
-			execute:       makePush(1, big.NewInt(1)),
+			execute:       makePush(1, 1),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH2: {
-			execute:       makePush(2, big.NewInt(2)),
+			execute:       makePush(2, 2),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH3: {
-			execute:       makePush(3, big.NewInt(3)),
+			execute:       makePush(3, 3),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH4: {
-			execute:       makePush(4, big.NewInt(4)),
+			execute:       makePush(4, 4),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH5: {
-			execute:       makePush(5, big.NewInt(5)),
+			execute:       makePush(5, 5),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH6: {
-			execute:       makePush(6, big.NewInt(6)),
+			execute:       makePush(6, 6),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH7: {
-			execute:       makePush(7, big.NewInt(7)),
+			execute:       makePush(7, 7),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH8: {
-			execute:       makePush(8, big.NewInt(8)),
+			execute:       makePush(8, 8),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH9: {
-			execute:       makePush(9, big.NewInt(9)),
+			execute:       makePush(9, 9),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH10: {
-			execute:       makePush(10, big.NewInt(10)),
+			execute:       makePush(10, 10),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH11: {
-			execute:       makePush(11, big.NewInt(11)),
+			execute:       makePush(11, 11),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH12: {
-			execute:       makePush(12, big.NewInt(12)),
+			execute:       makePush(12, 12),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH13: {
-			execute:       makePush(13, big.NewInt(13)),
+			execute:       makePush(13, 13),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH14: {
-			execute:       makePush(14, big.NewInt(14)),
+			execute:       makePush(14, 14),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH15: {
-			execute:       makePush(15, big.NewInt(15)),
+			execute:       makePush(15, 15),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH16: {
-			execute:       makePush(16, big.NewInt(16)),
+			execute:       makePush(16, 16),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH17: {
-			execute:       makePush(17, big.NewInt(17)),
+			execute:       makePush(17, 17),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH18: {
-			execute:       makePush(18, big.NewInt(18)),
+			execute:       makePush(18, 18),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH19: {
-			execute:       makePush(19, big.NewInt(19)),
+			execute:       makePush(19, 19),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH20: {
-			execute:       makePush(20, big.NewInt(20)),
+			execute:       makePush(20, 20),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH21: {
-			execute:       makePush(21, big.NewInt(21)),
+			execute:       makePush(21, 21),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH22: {
-			execute:       makePush(22, big.NewInt(22)),
+			execute:       makePush(22, 22),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH23: {
-			execute:       makePush(23, big.NewInt(23)),
+			execute:       makePush(23, 23),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH24: {
-			execute:       makePush(24, big.NewInt(24)),
+			execute:       makePush(24, 24),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH25: {
-			execute:       makePush(25, big.NewInt(25)),
+			execute:       makePush(25, 25),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH26: {
-			execute:       makePush(26, big.NewInt(26)),
+			execute:       makePush(26, 26),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH27: {
-			execute:       makePush(27, big.NewInt(27)),
+			execute:       makePush(27, 27),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH28: {
-			execute:       makePush(28, big.NewInt(28)),
+			execute:       makePush(28, 28),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH29: {
-			execute:       makePush(29, big.NewInt(29)),
+			execute:       makePush(29, 29),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH30: {
-			execute:       makePush(30, big.NewInt(30)),
+			execute:       makePush(30, 30),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH31: {
-			execute:       makePush(31, big.NewInt(31)),
+			execute:       makePush(31, 31),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
 		},
 		PUSH32: {
-			execute:       makePush(32, big.NewInt(32)),
+			execute:       makePush(32, 32),
 			gasCost:       gasPush,
 			validateStack: makeStackFunc(0, 1),
 			valid:         true,
