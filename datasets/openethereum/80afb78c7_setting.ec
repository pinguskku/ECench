commit 80afb78c7f41d8af5b4da757be0a25d772d958f4
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Sun Oct 2 09:40:54 2016 +0200

    Disabling debug symbols due to rustc 1.12 memory usage

diff --git a/Cargo.toml b/Cargo.toml
index 84edb6c1e..edcb145af 100644
--- a/Cargo.toml
+++ b/Cargo.toml
@@ -76,6 +76,6 @@ path = "parity/main.rs"
 name = "parity"
 
 [profile.release]
-debug = true
+debug = false
 lto = false
 
