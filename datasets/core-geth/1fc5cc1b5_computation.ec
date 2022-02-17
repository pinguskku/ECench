commit 1fc5cc1b598ef52f8f95ce47697dcc6993ac480d
Author: Bas van Kervel <bas@ethdev.com>
Date:   Mon Nov 28 17:14:55 2016 +0100

    node: improve error handling for web3_sha3 RPC method

diff --git a/node/api.go b/node/api.go
index 631e92c8e..7c9ad601a 100644
--- a/node/api.go
+++ b/node/api.go
@@ -21,7 +21,7 @@ import (
 	"strings"
 	"time"
 
-	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/hexutil"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/discover"
@@ -331,6 +331,6 @@ func (s *PublicWeb3API) ClientVersion() string {
 
 // Sha3 applies the ethereum sha3 implementation on the input.
 // It assumes the input is hex encoded.
-func (s *PublicWeb3API) Sha3(input string) string {
-	return common.ToHex(crypto.Keccak256(common.FromHex(input)))
+func (s *PublicWeb3API) Sha3(input hexutil.Bytes) hexutil.Bytes {
+	return crypto.Keccak256(input)
 }
