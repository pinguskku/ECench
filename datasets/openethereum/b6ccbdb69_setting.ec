commit b6ccbdb6949a3d2a3a9b85b34fa7a6ece0fd1e0c
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Tue Feb 16 23:37:24 2016 +0100

    Lower max handshakes to reduce network load

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index bcb1c7585..9560ca81e 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -46,8 +46,8 @@ type Slab<T> = ::slab::Slab<T, usize>;
 
 const _DEFAULT_PORT: u16 = 30304;
 const MAX_SESSIONS: usize = 1024;
-const MAX_HANDSHAKES: usize = 256;
-const MAX_HANDSHAKES_PER_ROUND: usize = 64;
+const MAX_HANDSHAKES: usize = 64;
+const MAX_HANDSHAKES_PER_ROUND: usize = 8;
 const MAINTENANCE_TIMEOUT: u64 = 1000;
 
 #[derive(Debug)]
