commit 37922dee69e8f94349caa86675ed731e3a8b50bf
Author: meows <b5c6@protonmail.com>
Date:   Sun Nov 15 05:28:24 2020 -0600

    node: (lint) remove unnecessary use of Sprintf
    
    2020-11-15 05:28:24-06:00
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/node/defaults.go b/node/defaults.go
index e048d1d09..21e7ec6c5 100644
--- a/node/defaults.go
+++ b/node/defaults.go
@@ -48,4 +48,3 @@ var DefaultConfig = Config{
 		NAT:        nat.Any(),
 	},
 }
-
diff --git a/node/openrpc.go b/node/openrpc.go
index 9bf6198c9..8db4938c7 100644
--- a/node/openrpc.go
+++ b/node/openrpc.go
@@ -276,14 +276,14 @@ var blockNumberOrHashD = fmt.Sprintf(`{
           ]
         }`, blockNumberD, commonHashD, requireCanonicalD)
 
-var rpcSubscriptionParamsNameD = fmt.Sprintf(`{
+var rpcSubscriptionParamsNameD = `{
 		"oneOf": [
 			{"type": "string", "enum": ["newHeads"], "description": "Fires a notification each time a new header is appended to the chain, including chain reorganizations."},
 			{"type": "string", "enum": ["logs"], "description": "Returns logs that are included in new imported blocks and match the given filter criteria."},
 			{"type": "string", "enum": ["newPendingTransactions"], "description": "Returns the hash for all transactions that are added to the pending state and are signed with a key that is available in the node."},
 			{"type": "string", "enum": ["syncing"], "description": "Indicates when the node starts or stops synchronizing. The result can either be a boolean indicating that the synchronization has started (true), finished (false) or an object with various progress indicators."}
 		]
-	}`)
+	}`
 
 // schemaDictEntry represents a type association passed to the jsonschema reflector.
 type schemaDictEntry struct {
@@ -410,7 +410,6 @@ var (
 	contextType      = reflect.TypeOf((*context.Context)(nil)).Elem()
 	errorType        = reflect.TypeOf((*error)(nil)).Elem()
 	subscriptionType = reflect.TypeOf(rpc.Subscription{})
-	stringType       = reflect.TypeOf("")
 )
 
 // Is t context.Context or *context.Context?
