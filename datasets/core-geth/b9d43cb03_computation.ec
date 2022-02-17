commit b9d43cb0376fe3a42b377af7e0062a06f467a11e
Author: meows <b5c6@protonmail.com>
Date:   Fri Oct 30 10:15:10 2020 -0500

    node: remove unnecessary use of fmt.Sprintf
    
    Sprintf is used elsewhere to interpolate type
    strings, but not here.
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/node/openrpc.go b/node/openrpc.go
index 369082580..e7c288555 100644
--- a/node/openrpc.go
+++ b/node/openrpc.go
@@ -139,11 +139,11 @@ func OpenRPCJSONSchemaTypeMapper(ty reflect.Type) *jsonschema.Type {
 		{rpc.BlockNumber(0), blockNumberD},
 		{rpc.BlockNumberOrHash{}, blockNumberOrHashD},
 
-		{rpc.Subscription{}, fmt.Sprintf(`{
+		{rpc.Subscription{}, `{
 			"type": "object",
 			"title": "Subscription",
 			"summary": ""
-		}`)},
+		}`},
 	}
 
 	for _, d := range dict {
