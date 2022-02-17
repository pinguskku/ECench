commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
commit d791fe4975fa62618f854a86f1648d5fe7081b79
Author: Taylor Gerring <taylor.gerring@gmail.com>
Date:   Thu Mar 19 23:34:35 2015 -0400

    Remove unnecessary event mux

diff --git a/rpc/api.go b/rpc/api.go
index f31b9a344..cef5e4689 100644
--- a/rpc/api.go
+++ b/rpc/api.go
@@ -12,7 +12,6 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/ethdb"
-	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/xeth"
 )
 
@@ -24,7 +23,6 @@ var (
 type EthereumApi struct {
 	eth    *xeth.XEth
 	xethMu sync.RWMutex
-	mux    *event.TypeMux
 
 	// // Register keeps a list of accounts and transaction data
 	// regmut   sync.Mutex
@@ -34,10 +32,10 @@ type EthereumApi struct {
 }
 
 func NewEthereumApi(eth *xeth.XEth, dataDir string) *EthereumApi {
+	// What about when dataDir is empty?
 	db, _ := ethdb.NewLDBDatabase(path.Join(dataDir, "dapps"))
 	api := &EthereumApi{
 		eth: eth,
-		mux: eth.Backend().EventMux(),
 		db:  db,
 	}
 
