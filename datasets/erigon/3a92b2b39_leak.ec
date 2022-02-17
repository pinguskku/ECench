commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
commit 3a92b2b39d2363a83a342fde849ffcbe2eb04444
Author: ledgerwatch <akhounov@gmail.com>
Date:   Sat Sep 5 21:58:51 2020 +0100

    Fix for RPC daemon leak (#1059)
    
    * Start memory prof
    
    * Fix rpctest
    
    * Fix rpctest
    
    * Attempt to fix the leak
    
    * Remove http pprof

diff --git a/cmd/rpcdaemon/main.go b/cmd/rpcdaemon/main.go
index 3ea6d11d4..8653852ed 100644
--- a/cmd/rpcdaemon/main.go
+++ b/cmd/rpcdaemon/main.go
@@ -1,9 +1,10 @@
 package main
 
 import (
-	"github.com/ledgerwatch/turbo-geth/cmd/utils"
 	"os"
 
+	"github.com/ledgerwatch/turbo-geth/cmd/utils"
+
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/cli"
 	"github.com/ledgerwatch/turbo-geth/cmd/rpcdaemon/commands"
 	"github.com/ledgerwatch/turbo-geth/log"
diff --git a/cmd/rpctest/rpctest/bench1.go b/cmd/rpctest/rpctest/bench1.go
index 5d1a4f628..b4cfff82a 100644
--- a/cmd/rpctest/rpctest/bench1.go
+++ b/cmd/rpctest/rpctest/bench1.go
@@ -4,12 +4,13 @@ import (
 	"bytes"
 	"encoding/base64"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
 	"net/http"
 	"os"
 	"path"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
 )
 
 var routes map[string]string
@@ -127,34 +128,36 @@ func Bench1(tgURL, gethURL string, needCompare bool, fullTest bool) {
 
 					}
 
-					for nextKeyG != nil {
-						var srGeth DebugStorageRange
-						res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
-						resultsCh <- res
-						if res.Err != nil {
-							fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
-							return
-						}
-						if srGeth.Error != nil {
-							fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
-							break
-						} else {
-							for k, v := range srGeth.Result.Storage {
-								smg[k] = v
-								if v.Key == nil {
-									fmt.Printf("%x: %x", k, v)
+					if needCompare {
+						for nextKeyG != nil {
+							var srGeth DebugStorageRange
+							res = reqGen.Geth("debug_storageRangeAt", reqGen.storageRangeAt(b.Result.Hash, i, tx.To, *nextKeyG), &srGeth)
+							resultsCh <- res
+							if res.Err != nil {
+								fmt.Printf("Could not get storageRange (geth): %s: %v\n", tx.Hash, res.Err)
+								return
+							}
+							if srGeth.Error != nil {
+								fmt.Printf("Error getting storageRange (geth): %d %s\n", srGeth.Error.Code, srGeth.Error.Message)
+								break
+							} else {
+								for k, v := range srGeth.Result.Storage {
+									smg[k] = v
+									if v.Key == nil {
+										fmt.Printf("%x: %x", k, v)
+									}
 								}
+								nextKeyG = srGeth.Result.NextKey
 							}
-							nextKeyG = srGeth.Result.NextKey
 						}
-					}
-					if !compareStorageRanges(sm, smg) {
-						fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
-						fmt.Printf("================sm\n")
-						printStorageRange(sm)
-						fmt.Printf("================smg\n")
-						printStorageRange(smg)
-						return
+						if !compareStorageRanges(sm, smg) {
+							fmt.Printf("len(sm) %d, len(smg) %d\n", len(sm), len(smg))
+							fmt.Printf("================sm\n")
+							printStorageRange(sm)
+							fmt.Printf("================smg\n")
+							printStorageRange(smg)
+							return
+						}
 					}
 				}
 			}
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index 0865cfd06..619fa38ed 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -4,14 +4,15 @@ import (
 	"bytes"
 	"encoding/json"
 	"fmt"
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/core/state"
-	"github.com/ledgerwatch/turbo-geth/crypto"
-	"github.com/ledgerwatch/turbo-geth/log"
 	"io"
 	"net/http"
 	"strings"
 	"time"
+
+	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/core/state"
+	"github.com/ledgerwatch/turbo-geth/crypto"
+	"github.com/ledgerwatch/turbo-geth/log"
 )
 
 func compareBlocks(b, bg *EthBlockByNumber) bool {
@@ -425,6 +426,7 @@ func print(client *http.Client, url, request string) {
 }
 
 func setRoutes(tgUrl, gethURL string) {
+	routes = make(map[string]string)
 	routes[TurboGeth] = tgUrl
 	routes[Geth] = gethURL
 }
diff --git a/ethdb/kv_remote.go b/ethdb/kv_remote.go
index c8fbe9185..0963ed955 100644
--- a/ethdb/kv_remote.go
+++ b/ethdb/kv_remote.go
@@ -54,6 +54,7 @@ type remoteCursor struct {
 	ctx                context.Context
 	prefix             []byte
 	stream             remote.KV_SeekClient
+	streamCancelFn     context.CancelFunc // this function needs to be called to close the stream
 	tx                 *remoteTx
 	bucketName         string
 }
@@ -186,7 +187,7 @@ func (tx *remoteTx) Commit(ctx context.Context) error {
 func (tx *remoteTx) Rollback() {
 	for _, c := range tx.cursors {
 		if c.stream != nil {
-			_ = c.stream.CloseSend()
+			c.streamCancelFn()
 			c.stream = nil
 		}
 	}
@@ -217,7 +218,7 @@ func (tx *remoteTx) Get(bucket string, key []byte) (val []byte, err error) {
 			if v.stream == nil {
 				return
 			}
-			_ = v.stream.CloseSend()
+			v.streamCancelFn()
 		}
 	}()
 
@@ -269,13 +270,15 @@ func (c *remoteCursor) First() ([]byte, []byte, error) {
 // .Next() - does request streaming (if configured by user)
 func (c *remoteCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	if c.stream != nil {
-		_ = c.stream.CloseSend()
+		c.streamCancelFn() // This will close the stream and free resources
 		c.stream = nil
 	}
 	c.initialized = true
 
 	var err error
-	c.stream, err = c.tx.db.remoteKV.Seek(c.ctx)
+	var streamCtx context.Context
+	streamCtx, c.streamCancelFn = context.WithCancel(c.ctx) // We create child context for the stream so we can cancel it to prevent leak
+	c.stream, err = c.tx.db.remoteKV.Seek(streamCtx)
 	if err != nil {
 		return []byte{}, nil, err
 	}
