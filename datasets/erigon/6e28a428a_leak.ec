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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
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
-commit d90d1db609c8d77baa422d49bd371207c06b4711
-Author: Felix Lange <fjl@twurst.com>
-Date:   Tue Dec 10 12:39:14 2019 +0100
-
-    eth/filters: remove use of event.TypeMux for pending logs (#20312)
-
-commit b8bc9b3d8e603ca6de70f5f6c38976514e1fb88e
-Merge: cecc7230c f383eaa10
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Tue Dec 10 13:31:25 2019 +0200
-
-    Merge pull request #20444 from MariusVanDerWijden/patch-4
-    
-    core: removed old invalid comment
-
-commit f383eaa102d11490a85c0a238f904e5d06b95178
-Author: Marius van der Wijden <m.vanderwijden@live.de>
-Date:   Tue Dec 10 11:50:16 2019 +0100
-
-    core: removed old invalid comment
-
-commit cecc7230c054dd1a4fc2783ad558bfa6e92062fe
-Author: Martin Holst Swende <martin@swende.se>
-Date:   Tue Dec 10 10:57:37 2019 +0100
-
-    tests/fuzzers: fuzzbuzz fuzzers for keystore, rlp, trie, whisper  (#19910)
-    
-    * fuzzers: fuzzers for keystore, rlp, trie, whisper (cred to @guidovranken)
-    
-    * fuzzers: move fuzzers to testdata
-    
-    * testdata/fuzzers: documentation
-    
-    * testdata/fuzzers: corpus for rlp
-    
-    * tests/fuzzers: fixup
-
-commit 4b40b5377b5069141cbb87026da96b079f393fff
-Author: Charing <pip1998@foxmail.com>
-Date:   Tue Dec 10 16:26:07 2019 +0800
-
-    miner: add dependency for stress tests (#20436)
-    
-    1.to build stress tests
-    
-    Depends-On: 6269e5574c024bb82617b33f673550231b3a3b37
-
-commit 370cb95b7ff5990879a4f47fcc818be7d6366357
-Author: Péter Szilágyi <peterke@gmail.com>
-Date:   Fri Dec 6 11:53:25 2019 +0200
-
-    params: begin v1.9.10 release cycle
+    * p2p/dnsdisc: tiny comment fix
\ No newline at end of file
