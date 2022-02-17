commit 5183483c53fac7ad5d31759ecb95ca7b1a67744d
Author: Christian Muehlhaeuser <muesli@gmail.com>
Date:   Mon Jul 22 09:30:09 2019 +0200

    core/state, p2p/discover, trie, whisper: avoid unnecessary conversions (#19870)
    
    No need to convert these types.

diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index c78ef38fd..bf073bc94 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -86,15 +86,15 @@ func TestIntermediateLeaks(t *testing.T) {
 
 	// Modify the transient state.
 	for i := byte(0); i < 255; i++ {
-		modify(transState, common.Address{byte(i)}, i, 0)
+		modify(transState, common.Address{i}, i, 0)
 	}
 	// Write modifications to trie.
 	transState.IntermediateRoot(false)
 
 	// Overwrite all the data with new values in the transient database.
 	for i := byte(0); i < 255; i++ {
-		modify(transState, common.Address{byte(i)}, i, 99)
-		modify(finalState, common.Address{byte(i)}, i, 99)
+		modify(transState, common.Address{i}, i, 99)
+		modify(finalState, common.Address{i}, i, 99)
 	}
 
 	// Commit and cross check the databases.
diff --git a/p2p/discover/v4_udp_test.go b/p2p/discover/v4_udp_test.go
index c4f5b5de0..b4e024e7e 100644
--- a/p2p/discover/v4_udp_test.go
+++ b/p2p/discover/v4_udp_test.go
@@ -454,7 +454,7 @@ func TestUDPv4_successfulPing(t *testing.T) {
 		if !n.IP().Equal(test.remoteaddr.IP) {
 			t.Errorf("node has wrong IP: got %v, want: %v", n.IP(), test.remoteaddr.IP)
 		}
-		if int(n.UDP()) != test.remoteaddr.Port {
+		if n.UDP() != test.remoteaddr.Port {
 			t.Errorf("node has wrong UDP port: got %v, want: %v", n.UDP(), test.remoteaddr.Port)
 		}
 		if n.TCP() != int(testRemote.TCP) {
diff --git a/trie/trie_test.go b/trie/trie_test.go
index ea0b3cbdd..2a9d53d0a 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -52,7 +52,7 @@ func TestEmptyTrie(t *testing.T) {
 	var trie Trie
 	res := trie.Hash()
 	exp := emptyRoot
-	if res != common.Hash(exp) {
+	if res != exp {
 		t.Errorf("expected %x got %x", exp, res)
 	}
 }
diff --git a/whisper/whisperv6/whisper_test.go b/whisper/whisperv6/whisper_test.go
index 895bb2b96..39c2abf04 100644
--- a/whisper/whisperv6/whisper_test.go
+++ b/whisper/whisperv6/whisper_test.go
@@ -76,7 +76,7 @@ func TestWhisperBasic(t *testing.T) {
 		t.Fatalf("failed w.Envelopes().")
 	}
 
-	derived := pbkdf2.Key([]byte(peerID), nil, 65356, aesKeyLength, sha256.New)
+	derived := pbkdf2.Key(peerID, nil, 65356, aesKeyLength, sha256.New)
 	if !validateDataIntegrity(derived, aesKeyLength) {
 		t.Fatalf("failed validateSymmetricKey with param = %v.", derived)
 	}
