commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
commit 6fdddc5ac940b6241596e0a2622461148e8a57a0
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Jun 29 11:13:28 2015 +0200

    improved error handling in parsing request

diff --git a/rpc/api/eth.go b/rpc/api/eth.go
index 1883e363c..8e9647861 100644
--- a/rpc/api/eth.go
+++ b/rpc/api/eth.go
@@ -12,6 +12,7 @@ import (
 	"github.com/ethereum/go-ethereum/rpc/shared"
 	"github.com/ethereum/go-ethereum/xeth"
 	"gopkg.in/fatih/set.v0"
+	"fmt"
 )
 
 const (
@@ -574,7 +575,7 @@ func (self *ethApi) Resend(req *shared.Request) (interface{}, error) {
 func (self *ethApi) PendingTransactions(req *shared.Request) (interface{}, error) {
 	txs := self.ethereum.TxPool().GetTransactions()
 
-	// grab the accounts from the account manager. This will help with determening which
+	// grab the accounts from the account manager. This will help with determining which
 	// transactions should be returned.
 	accounts, err := self.ethereum.AccountManager().Accounts()
 	if err != nil {
diff --git a/rpc/api/eth_args.go b/rpc/api/eth_args.go
index a75fdbdee..88fc00a6c 100644
--- a/rpc/api/eth_args.go
+++ b/rpc/api/eth_args.go
@@ -917,7 +917,11 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 	trans := new(tx)
 	err = json.Unmarshal(data, trans)
 	if err != nil {
-		return shared.NewDecodeParamError("Unable to parse transaction object.")
+		return shared.NewDecodeParamError("Unable to parse transaction object")
+	}
+
+	if trans == nil || trans.tx == nil {
+		return shared.NewDecodeParamError("Unable to parse transaction object")
 	}
 
 	gasLimit, gasPrice := trans.GasLimit, trans.GasPrice
@@ -936,6 +940,7 @@ func (args *ResendArgs) UnmarshalJSON(b []byte) (err error) {
 			return shared.NewInvalidTypeError("gasLimit", "not a string")
 		}
 	}
+
 	args.Tx = trans
 	args.GasPrice = gasPrice
 	args.GasLimit = gasLimit
