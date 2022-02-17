commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
commit e81069ab3d5ea06f2d7280981274eea5cb7f5a02
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Wed Jun 13 13:02:16 2018 +0200

    fixed ipc leak, closes #8774 (#8876)

diff --git a/Cargo.lock b/Cargo.lock
index 835ea1c6f..b1b156dba 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1366,7 +1366,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-core"
 version = "8.0.1"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1378,7 +1378,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-http-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "hyper 0.11.24 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1391,7 +1391,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ipc-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1403,7 +1403,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-macros"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-pubsub 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1413,7 +1413,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-pubsub"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1423,7 +1423,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-server-utils"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "globset 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1436,7 +1436,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-tcp-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
  "jsonrpc-server-utils 8.0.0 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1448,7 +1448,7 @@ dependencies = [
 [[package]]
 name = "jsonrpc-ws-server"
 version = "8.0.0"
-source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#06bec6ab682ec4ce16d7e7daf2612870c4272028"
+source = "git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11#c8e6336798be4444953def351099078617d40efd"
 dependencies = [
  "error-chain 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "jsonrpc-core 8.0.1 (git+https://github.com/paritytech/jsonrpc.git?branch=parity-1.11)",
@@ -1730,14 +1730,13 @@ dependencies = [
 
 [[package]]
 name = "mio-named-pipes"
-version = "0.1.4"
-source = "git+https://github.com/alexcrichton/mio-named-pipes#9c1bbb985b74374d3b7eda76937279f8e977ef81"
+version = "0.1.5"
+source = "git+https://github.com/alexcrichton/mio-named-pipes#6ad80e67fe7993423b281bc13d307785ade05d37"
 dependencies = [
- "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "log 0.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
+ "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)",
- "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -1760,6 +1759,15 @@ dependencies = [
  "ws2_32-sys 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "miow"
+version = "0.3.1"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "msdos_time"
 version = "0.1.6"
@@ -2267,12 +2275,12 @@ dependencies = [
 [[package]]
 name = "parity-tokio-ipc"
 version = "0.1.5"
-source = "git+https://github.com/nikvolf/parity-tokio-ipc#d6c5b3cfcc913a1b9cf0f0562a10b083ceb9fb7c"
+source = "git+https://github.com/nikvolf/parity-tokio-ipc#2af3e5b6b746552d8181069a2c6be068377df1de"
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2672,7 +2680,7 @@ dependencies = [
 
 [[package]]
 name = "redox_syscall"
-version = "0.1.31"
+version = "0.1.40"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
@@ -2680,7 +2688,7 @@ name = "redox_termios"
 version = "0.1.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3015,6 +3023,17 @@ dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "socket2"
+version = "0.3.6"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
+ "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "stable_deref_trait"
 version = "1.0.0"
@@ -3114,7 +3133,7 @@ dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.20 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3143,7 +3162,7 @@ version = "1.5.1"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3161,7 +3180,7 @@ version = "3.3.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3189,7 +3208,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.36 (registry+https://github.com/rust-lang/crates.io-index)",
- "redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)",
+ "redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3268,7 +3287,7 @@ source = "git+https://github.com/nikvolf/tokio-named-pipes#0b9b728eaeb0a6673c287
 dependencies = [
  "bytes 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.21 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)",
+ "mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)",
  "tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3893,9 +3912,10 @@ dependencies = [
 "checksum miniz_oxide 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "aaa2d3ad070f428fffbd7d3ca2ea20bb0d8cffe9024405c44e1840bc1418b398"
 "checksum miniz_oxide_c_api 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "92d98fdbd6145645828069b37ea92ca3de225e000d80702da25c20d3584b38a5"
 "checksum mio 0.6.14 (registry+https://github.com/rust-lang/crates.io-index)" = "6d771e3ef92d58a8da8df7d6976bfca9371ed1de6619d9d5a5ce5b1f29b85bfe"
-"checksum mio-named-pipes 0.1.4 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
+"checksum mio-named-pipes 0.1.5 (git+https://github.com/alexcrichton/mio-named-pipes)" = "<none>"
 "checksum mio-uds 0.6.4 (registry+https://github.com/rust-lang/crates.io-index)" = "1731a873077147b626d89cc6c2a0db6288d607496c5d10c0cfcf3adc697ec673"
 "checksum miow 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)" = "8c1f2f3b1cf331de6896aabf6e9d55dca90356cc9960cca7eaaf408a355ae919"
+"checksum miow 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "9224c91f82b3c47cf53dcf78dfaa20d6888fbcc5d272d5f2fcdf8a697f3c987d"
 "checksum msdos_time 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "aad9dfe950c057b1bfe9c1f2aa51583a8468ef2a5baba2ebbe06d775efeb7729"
 "checksum multibase 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b9c35dac080fd6e16a99924c8dfdef0af89d797dd851adab25feaffacf7850d6"
 "checksum multihash 0.7.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7d49add5f49eb08bfc4d01ff286b84a48f53d45314f165c2d6efe477222d24f3"
@@ -3948,7 +3968,7 @@ dependencies = [
 "checksum rand 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)" = "eba5f8cb59cc50ed56be8880a5c7b496bfd9bd26394e176bc67884094145c2c5"
 "checksum rayon 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "80e811e76f1dbf68abf87a759083d34600017fc4e10b6bd5ad84a700f9dba4b1"
 "checksum rayon-core 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d24ad214285a7729b174ed6d3bcfcb80177807f959d95fafd5bfc5c4f201ac8"
-"checksum redox_syscall 0.1.31 (registry+https://github.com/rust-lang/crates.io-index)" = "8dde11f18c108289bef24469638a04dce49da56084f2d50618b226e47eb04509"
+"checksum redox_syscall 0.1.40 (registry+https://github.com/rust-lang/crates.io-index)" = "c214e91d3ecf43e9a4e41e578973adeb14b474f2bee858742d127af75a0112b1"
 "checksum redox_termios 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "7e891cfe48e9100a70a3b6eb652fef28920c117d366339687bd5576160db0f76"
 "checksum regex 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "744554e01ccbd98fff8c457c3b092cd67af62a555a43bfe97ae8a0451f7799fa"
 "checksum regex-syntax 0.4.1 (registry+https://github.com/rust-lang/crates.io-index)" = "ad890a5eef7953f55427c50575c680c42841653abd2b028b68cd223d157f62db"
@@ -3987,6 +4007,7 @@ dependencies = [
 "checksum smallvec 0.4.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8fcd03faf178110ab0334d74ca9631d77f94c8c11cc77fcb59538abf0025695d"
 "checksum snappy 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
 "checksum snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)" = "<none>"
+"checksum socket2 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "06dc9f86ee48652b7c80f3d254e3b9accb67a928c562c64d10d7b016d3d98dab"
 "checksum stable_deref_trait 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "15132e0e364248108c5e2c02e3ab539be8d6f5d52a01ca9bbf27ed657316f02b"
 "checksum strsim 0.6.0 (registry+https://github.com/rust-lang/crates.io-index)" = "b4d15c810519a91cf877e7e36e63fe068815c678181439f2f29e2562147c3694"
 "checksum syn 0.13.1 (registry+https://github.com/rust-lang/crates.io-index)" = "91b52877572087400e83d24b9178488541e3d535259e04ff17a63df1e5ceff59"
