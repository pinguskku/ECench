commit 08c26ab8b0142778393924211188f0d06deef0ce
Author: obscuren <geffobscura@gmail.com>
Date:   Sun Oct 26 20:09:51 2014 +0100

    Removed unnecessary code.

diff --git a/ethtrie/trie.go b/ethtrie/trie.go
index 7a86e79bd..686971985 100644
--- a/ethtrie/trie.go
+++ b/ethtrie/trie.go
@@ -3,15 +3,12 @@ package ethtrie
 import (
 	"bytes"
 	"fmt"
-	_ "reflect"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/ethcrypto"
 	"github.com/ethereum/go-ethereum/ethutil"
 )
 
-func __ignore() { fmt.Println("") }
-
 func ParanoiaCheck(t1 *Trie) (bool, *Trie) {
 	t2 := New(ethutil.Config.Db, "")
 
