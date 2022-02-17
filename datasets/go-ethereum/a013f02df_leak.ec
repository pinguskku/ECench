commit a013f02df2329fafc08f23cd623df6afa7471d20
Author: wangxiang <scottwangsxll@gmail.com>
Date:   Wed Jan 8 01:08:22 2020 +0800

    whisper/whisperv6: fix peer time.Ticker leak (#20520)

diff --git a/whisper/whisperv6/peer.go b/whisper/whisperv6/peer.go
index 4451f1495..29d8bdf17 100644
--- a/whisper/whisperv6/peer.go
+++ b/whisper/whisperv6/peer.go
@@ -146,7 +146,9 @@ func (peer *Peer) handshake() error {
 func (peer *Peer) update() {
 	// Start the tickers for the updates
 	expire := time.NewTicker(expirationCycle)
+	defer expire.Stop()
 	transmit := time.NewTicker(transmissionCycle)
+	defer transmit.Stop()
 
 	// Loop and transmit until termination is requested
 	for {
