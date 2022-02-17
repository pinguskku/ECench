commit 0ff2adb21b4d9a4699f50b1d1a65873fac39d258
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Feb 15 10:13:39 2016 +0100

    core: improved check for contract creation

diff --git a/core/state_transition.go b/core/state_transition.go
index 7ecc01d4c..12c3ab3a1 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -73,7 +73,7 @@ func MessageCreatesContract(msg Message) bool {
 	return msg.To() == nil
 }
 
-// IntrinsicGas computes the 'intrisic gas' for a message
+// IntrinsicGas computes the 'intrinsic gas' for a message
 // with the given data.
 func IntrinsicGas(data []byte) *big.Int {
 	igas := new(big.Int).Set(params.TxGas)
diff --git a/eth/api.go b/eth/api.go
index 37b033dc6..4b26396aa 100644
--- a/eth/api.go
+++ b/eth/api.go
@@ -619,12 +619,12 @@ func (m callmsg) Value() *big.Int               { return m.value }
 func (m callmsg) Data() []byte                  { return m.data }
 
 type CallArgs struct {
-	From     common.Address `json:"from"`
-	To       common.Address `json:"to"`
-	Gas      rpc.HexNumber  `json:"gas"`
-	GasPrice rpc.HexNumber  `json:"gasPrice"`
-	Value    rpc.HexNumber  `json:"value"`
-	Data     string         `json:"data"`
+	From     common.Address  `json:"from"`
+	To       *common.Address `json:"to"`
+	Gas      rpc.HexNumber   `json:"gas"`
+	GasPrice rpc.HexNumber   `json:"gasPrice"`
+	Value    rpc.HexNumber   `json:"value"`
+	Data     string          `json:"data"`
 }
 
 func (s *PublicBlockChainAPI) doCall(args CallArgs, blockNr rpc.BlockNumber) (string, *big.Int, error) {
@@ -652,7 +652,7 @@ func (s *PublicBlockChainAPI) doCall(args CallArgs, blockNr rpc.BlockNumber) (st
 	// Assemble the CALL invocation
 	msg := callmsg{
 		from:     from,
-		to:       &args.To,
+		to:       args.To,
 		gas:      args.Gas.BigInt(),
 		gasPrice: args.GasPrice.BigInt(),
 		value:    args.Value.BigInt(),
@@ -664,6 +664,7 @@ func (s *PublicBlockChainAPI) doCall(args CallArgs, blockNr rpc.BlockNumber) (st
 	if msg.gasPrice.Cmp(common.Big0) == 0 {
 		msg.gasPrice = new(big.Int).Mul(big.NewInt(50), common.Shannon)
 	}
+
 	// Execute the call and return
 	vmenv := core.NewEnv(stateDb, s.bc, msg, block.Header())
 	gp := new(core.GasPool).AddGas(common.MaxBig)
@@ -1011,13 +1012,13 @@ func (s *PublicTransactionPoolAPI) sign(address common.Address, tx *types.Transa
 }
 
 type SendTxArgs struct {
-	From     common.Address `json:"from"`
-	To       common.Address `json:"to"`
-	Gas      *rpc.HexNumber `json:"gas"`
-	GasPrice *rpc.HexNumber `json:"gasPrice"`
-	Value    *rpc.HexNumber `json:"value"`
-	Data     string         `json:"data"`
-	Nonce    *rpc.HexNumber `json:"nonce"`
+	From     common.Address  `json:"from"`
+	To       *common.Address `json:"to"`
+	Gas      *rpc.HexNumber  `json:"gas"`
+	GasPrice *rpc.HexNumber  `json:"gasPrice"`
+	Value    *rpc.HexNumber  `json:"value"`
+	Data     string          `json:"data"`
+	Nonce    *rpc.HexNumber  `json:"nonce"`
 }
 
 // SendTransaction will create a transaction for the given transaction argument, sign it and submit it to the
@@ -1041,12 +1042,12 @@ func (s *PublicTransactionPoolAPI) SendTransaction(args SendTxArgs) (common.Hash
 	}
 
 	var tx *types.Transaction
-	contractCreation := (args.To == common.Address{})
+	contractCreation := (args.To == nil)
 
 	if contractCreation {
 		tx = types.NewContractCreation(args.Nonce.Uint64(), args.Value.BigInt(), args.Gas.BigInt(), args.GasPrice.BigInt(), common.FromHex(args.Data))
 	} else {
-		tx = types.NewTransaction(args.Nonce.Uint64(), args.To, args.Value.BigInt(), args.Gas.BigInt(), args.GasPrice.BigInt(), common.FromHex(args.Data))
+		tx = types.NewTransaction(args.Nonce.Uint64(), *args.To, args.Value.BigInt(), args.Gas.BigInt(), args.GasPrice.BigInt(), common.FromHex(args.Data))
 	}
 
 	signedTx, err := s.sign(args.From, tx)
@@ -1105,7 +1106,7 @@ func (s *PublicTransactionPoolAPI) Sign(address common.Address, data string) (st
 
 type SignTransactionArgs struct {
 	From     common.Address
-	To       common.Address
+	To       *common.Address
 	Nonce    *rpc.HexNumber
 	Value    *rpc.HexNumber
 	Gas      *rpc.HexNumber
@@ -1131,23 +1132,21 @@ type Tx struct {
 
 func (tx *Tx) UnmarshalJSON(b []byte) (err error) {
 	req := struct {
-		To       common.Address `json:"to"`
-		From     common.Address `json:"from"`
-		Nonce    *rpc.HexNumber `json:"nonce"`
-		Value    *rpc.HexNumber `json:"value"`
-		Data     string         `json:"data"`
-		GasLimit *rpc.HexNumber `json:"gas"`
-		GasPrice *rpc.HexNumber `json:"gasPrice"`
-		Hash     common.Hash    `json:"hash"`
+		To       *common.Address `json:"to"`
+		From     common.Address  `json:"from"`
+		Nonce    *rpc.HexNumber  `json:"nonce"`
+		Value    *rpc.HexNumber  `json:"value"`
+		Data     string          `json:"data"`
+		GasLimit *rpc.HexNumber  `json:"gas"`
+		GasPrice *rpc.HexNumber  `json:"gasPrice"`
+		Hash     common.Hash     `json:"hash"`
 	}{}
 
 	if err := json.Unmarshal(b, &req); err != nil {
 		return err
 	}
 
-	contractCreation := (req.To == (common.Address{}))
-
-	tx.To = &req.To
+	tx.To = req.To
 	tx.From = req.From
 	tx.Nonce = req.Nonce
 	tx.Value = req.Value
@@ -1171,12 +1170,10 @@ func (tx *Tx) UnmarshalJSON(b []byte) (err error) {
 		tx.GasPrice = rpc.NewHexNumber(int64(50000000000))
 	}
 
+	contractCreation := (req.To == nil)
 	if contractCreation {
 		tx.tx = types.NewContractCreation(tx.Nonce.Uint64(), tx.Value.BigInt(), tx.GasLimit.BigInt(), tx.GasPrice.BigInt(), data)
 	} else {
-		if tx.To == nil {
-			return fmt.Errorf("need to address")
-		}
 		tx.tx = types.NewTransaction(tx.Nonce.Uint64(), *tx.To, tx.Value.BigInt(), tx.GasLimit.BigInt(), tx.GasPrice.BigInt(), data)
 	}
 
@@ -1225,12 +1222,12 @@ func (s *PublicTransactionPoolAPI) SignTransaction(args *SignTransactionArgs) (*
 	}
 
 	var tx *types.Transaction
-	contractCreation := (args.To == common.Address{})
+	contractCreation := (args.To == nil)
 
 	if contractCreation {
 		tx = types.NewContractCreation(args.Nonce.Uint64(), args.Value.BigInt(), args.Gas.BigInt(), args.GasPrice.BigInt(), common.FromHex(args.Data))
 	} else {
-		tx = types.NewTransaction(args.Nonce.Uint64(), args.To, args.Value.BigInt(), args.Gas.BigInt(), args.GasPrice.BigInt(), common.FromHex(args.Data))
+		tx = types.NewTransaction(args.Nonce.Uint64(), *args.To, args.Value.BigInt(), args.Gas.BigInt(), args.GasPrice.BigInt(), common.FromHex(args.Data))
 	}
 
 	signedTx, err := s.sign(args.From, tx)
@@ -1323,7 +1320,7 @@ func (s *PublicTransactionPoolAPI) Resend(tx *Tx, gasPrice, gasLimit *rpc.HexNum
 			}
 
 			var newTx *types.Transaction
-			contractCreation := (*tx.tx.To() == common.Address{})
+			contractCreation := (tx.tx.To() == nil)
 			if contractCreation {
 				newTx = types.NewContractCreation(tx.tx.Nonce(), tx.tx.Value(), gasPrice.BigInt(), gasLimit.BigInt(), tx.tx.Data())
 			} else {
