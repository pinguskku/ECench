commit 6e28a428a8922a8fc8be4332b39163c1213077ed
Author: wangxiang <scottwangsxll@gmail.com>
Date:   Wed Jan 8 01:08:22 2020 +0800

    whisper/whisperv6: fix peer time.Ticker leak (#20520)

diff --git a/to-merge.txt b/to-merge.txt
index 0e61fcbf1..7f3779763 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -543,57 +543,4 @@ Date:   Thu Dec 12 10:15:36 2019 +0100
     
     * cmd/devp2p: adapt dnsClient to new p2p/dnsdisc API
     
-    * p2p/dnsdisc: tiny comment fix
-
