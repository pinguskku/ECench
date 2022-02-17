commit 1d1bee528e04f8d7c87b1808e39c95382f2dd8b2
Author: Guillaume Ballet <gballet@gmail.com>
Date:   Sun Mar 24 16:15:43 2019 +0100

    fix unnecessary condition linter warning

diff --git a/accounts/scwallet/securechannel.go b/accounts/scwallet/securechannel.go
index 7d57c4df9..3c9732198 100644
--- a/accounts/scwallet/securechannel.go
+++ b/accounts/scwallet/securechannel.go
@@ -88,7 +88,7 @@ func NewSecureChannelSession(card *pcsc.Card, keyData []byte) (*SecureChannelSes
 
 // Pair establishes a new pairing with the smartcard.
 func (s *SecureChannelSession) Pair(pairingPassword []byte) error {
-	secretHash := pbkdf2.Key(norm.NFKD.Bytes([]byte(pairingPassword)), norm.NFKD.Bytes([]byte(pairingSalt)), 50000, 32, sha256.New)
+	secretHash := pbkdf2.Key(norm.NFKD.Bytes(pairingPassword), norm.NFKD.Bytes([]byte(pairingSalt)), 50000, 32, sha256.New)
 
 	challenge := make([]byte, 32)
 	if _, err := rand.Read(challenge); err != nil {
