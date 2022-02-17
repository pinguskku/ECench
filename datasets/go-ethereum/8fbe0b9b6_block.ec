commit 8fbe0b9b68772af34c1dc3b4dd274f19df587636
Author: Evolution404 <35091674+Evolution404@users.noreply.github.com>
Date:   Thu Dec 2 17:55:01 2021 +0800

    p2p/enr: reduce allocation in Record.encode (#24034)

diff --git a/p2p/enr/enr.go b/p2p/enr/enr.go
index 05e43fd80..15891813b 100644
--- a/p2p/enr/enr.go
+++ b/p2p/enr/enr.go
@@ -304,7 +304,7 @@ func (r *Record) AppendElements(list []interface{}) []interface{} {
 }
 
 func (r *Record) encode(sig []byte) (raw []byte, err error) {
-	list := make([]interface{}, 1, 2*len(r.pairs)+1)
+	list := make([]interface{}, 1, 2*len(r.pairs)+2)
 	list[0] = sig
 	list = r.AppendElements(list)
 	if raw, err = rlp.EncodeToBytes(list); err != nil {
