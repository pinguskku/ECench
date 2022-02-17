commit 7d0ac94809e79b9d1aadb1899738595da6ff6103
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Apr 10 13:50:42 2017 +0200

    rpc: improve BlockNumber unmarshal parsing

diff --git a/rpc/types.go b/rpc/types.go
index d8d736efb..d29281a4a 100644
--- a/rpc/types.go
+++ b/rpc/types.go
@@ -19,11 +19,11 @@ package rpc
 import (
 	"fmt"
 	"math"
-	"math/big"
 	"reflect"
 	"strings"
 	"sync"
 
+	"github.com/ethereum/go-ethereum/common/hexutil"
 	"gopkg.in/fatih/set.v0"
 )
 
@@ -121,18 +121,12 @@ type ServerCodec interface {
 	Closed() <-chan interface{}
 }
 
-var (
-	pendingBlockNumber  = big.NewInt(-2)
-	latestBlockNumber   = big.NewInt(-1)
-	earliestBlockNumber = big.NewInt(0)
-	maxBlockNumber      = big.NewInt(math.MaxInt64)
-)
-
 type BlockNumber int64
 
 const (
-	PendingBlockNumber = BlockNumber(-2)
-	LatestBlockNumber  = BlockNumber(-1)
+	PendingBlockNumber  = BlockNumber(-2)
+	LatestBlockNumber   = BlockNumber(-1)
+	EarliestBlockNumber = BlockNumber(0)
 )
 
 // UnmarshalJSON parses the given JSON fragment into a BlockNumber. It supports:
@@ -143,45 +137,32 @@ const (
 // - an out of range error when the given block number is either too little or too large
 func (bn *BlockNumber) UnmarshalJSON(data []byte) error {
 	input := strings.TrimSpace(string(data))
-
 	if len(input) >= 2 && input[0] == '"' && input[len(input)-1] == '"' {
 		input = input[1 : len(input)-1]
 	}
 
-	if len(input) == 0 {
-		*bn = BlockNumber(latestBlockNumber.Int64())
+	switch input {
+	case "earliest":
+		*bn = EarliestBlockNumber
+		return nil
+	case "latest":
+		*bn = LatestBlockNumber
+		return nil
+	case "pending":
+		*bn = PendingBlockNumber
 		return nil
 	}
 
-	in := new(big.Int)
-	_, ok := in.SetString(input, 0)
-
-	if !ok { // test if user supplied string tag
-		strBlockNumber := input
-		if strBlockNumber == "latest" {
-			*bn = BlockNumber(latestBlockNumber.Int64())
-			return nil
-		}
-
-		if strBlockNumber == "earliest" {
-			*bn = BlockNumber(earliestBlockNumber.Int64())
-			return nil
-		}
-
-		if strBlockNumber == "pending" {
-			*bn = BlockNumber(pendingBlockNumber.Int64())
-			return nil
-		}
-
-		return fmt.Errorf(`invalid blocknumber %s`, data)
+	blckNum, err := hexutil.DecodeUint64(input)
+	if err != nil {
+		return err
 	}
-
-	if in.Cmp(earliestBlockNumber) >= 0 && in.Cmp(maxBlockNumber) <= 0 {
-		*bn = BlockNumber(in.Int64())
-		return nil
+	if blckNum > math.MaxInt64 {
+		return fmt.Errorf("Blocknumber too high")
 	}
 
-	return fmt.Errorf("blocknumber not in range [%d, %d]", earliestBlockNumber, maxBlockNumber)
+	*bn = BlockNumber(blckNum)
+	return nil
 }
 
 func (bn BlockNumber) Int64() int64 {
diff --git a/rpc/types_test.go b/rpc/types_test.go
new file mode 100644
index 000000000..30cef9b22
--- /dev/null
+++ b/rpc/types_test.go
@@ -0,0 +1,66 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package rpc
+
+import (
+	"encoding/json"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
+)
+
+func TestBlockNumberJSONUnmarshal(t *testing.T) {
+	tests := []struct {
+		input    string
+		mustFail bool
+		expected BlockNumber
+	}{
+		0:  {`"0x"`, true, BlockNumber(0)},
+		1:  {`"0x0"`, false, BlockNumber(0)},
+		2:  {`"0X1"`, false, BlockNumber(1)},
+		3:  {`"0x00"`, true, BlockNumber(0)},
+		4:  {`"0x01"`, true, BlockNumber(0)},
+		5:  {`"0x1"`, false, BlockNumber(1)},
+		6:  {`"0x12"`, false, BlockNumber(18)},
+		7:  {`"0x7fffffffffffffff"`, false, BlockNumber(math.MaxInt64)},
+		8:  {`"0x8000000000000000"`, true, BlockNumber(0)},
+		9:  {"0", true, BlockNumber(0)},
+		10: {`"ff"`, true, BlockNumber(0)},
+		11: {`"pending"`, false, PendingBlockNumber},
+		12: {`"latest"`, false, LatestBlockNumber},
+		13: {`"earliest"`, false, EarliestBlockNumber},
+		14: {`someString`, true, BlockNumber(0)},
+		15: {`""`, true, BlockNumber(0)},
+		16: {``, true, BlockNumber(0)},
+	}
+
+	for i, test := range tests {
+		var num BlockNumber
+		err := json.Unmarshal([]byte(test.input), &num)
+		if test.mustFail && err == nil {
+			t.Errorf("Test %d should fail", i)
+			continue
+		}
+		if !test.mustFail && err != nil {
+			t.Errorf("Test %d should pass but got err: %v", i, err)
+			continue
+		}
+		if num != test.expected {
+			t.Errorf("Test %d got unexpected value, want %d, got %d", i, test.expected, num)
+		}
+	}
+}
