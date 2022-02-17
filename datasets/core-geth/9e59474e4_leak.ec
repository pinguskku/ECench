commit 9e59474e46f383cd2eace981d498dd7176ea1319
Author: Shihao Xia <charlesxsh@hotmail.com>
Date:   Sun Aug 8 09:44:42 2021 -0400

    core/rawdb: close database in test to avoid goroutine leak (#23287)
    
    * add db close to avoid goroutine leak
    
    * core/rawdb: move close to defer
    
    Co-authored-by: Martin Holst Swende <martin@swende.se>

diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index ea9dc436c..f20e8b1ff 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -444,6 +444,7 @@ func TestAncientStorage(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create database with ancient backend")
 	}
+	defer db.Close()
 	// Create a test block
 	block := types.NewBlockWithHeader(&types.Header{
 		Number:      big.NewInt(0),
