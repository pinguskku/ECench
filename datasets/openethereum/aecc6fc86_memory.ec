commit aecc6fc862cf6682620281f3ca105cd1c483a5b4
Author: rakita <rakita@users.noreply.github.com>
Date:   Mon Sep 14 16:08:57 2020 +0200

    Prometheus, heavy memory calls removed (#27)

diff --git a/Cargo.lock b/Cargo.lock
index 0252b6f48..467240da2 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -113,6 +113,11 @@ name = "autocfg"
 version = "0.1.7"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
+[[package]]
+name = "autocfg"
+version = "1.0.0"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+
 [[package]]
 name = "backtrace"
 version = "0.3.40"
@@ -490,6 +495,16 @@ dependencies = [
  "crossbeam-utils 0.6.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "crossbeam-queue"
+version = "0.2.3"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "crossbeam-utils 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "maybe-uninit 2.0.0 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "crossbeam-utils"
 version = "0.6.6"
@@ -499,6 +514,16 @@ dependencies = [
  "lazy_static 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "crossbeam-utils"
+version = "0.7.2"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "autocfg 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "cfg-if 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "lazy_static 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "crunchy"
 version = "0.1.6"
@@ -579,9 +604,9 @@ name = "derive_more"
 version = "0.99.9"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -733,9 +758,9 @@ version = "0.2.0"
 source = "git+https://github.com/matter-labs/eip1962.git?rev=ece6cbabc41948db4200e41f0bfdab7ab94c7af8#ece6cbabc41948db4200e41f0bfdab7ab94c7af8"
 dependencies = [
  "byteorder 1.3.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -847,7 +872,7 @@ dependencies = [
  "lru-cache 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "macros 0.1.0",
  "memory-cache 0.1.0",
- "memory-db 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "memory-db 0.11.0",
  "num_cpus 1.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "parity-bytes 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "parity-runtime 0.1.0",
@@ -982,7 +1007,7 @@ dependencies = [
  "fnv 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "num_cpus 1.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "parking_lot 0.7.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "slab 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1077,7 +1102,7 @@ dependencies = [
  "libc 0.2.65 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
  "lru-cache 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "parity-bytes 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "parity-crypto 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "parity-path 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1199,6 +1224,7 @@ dependencies = [
  "rand 0.4.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "rlp 0.3.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "rustc-hex 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "stats 0.1.0",
  "trace-time 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "triehash-ethereum 0.2.0",
 ]
@@ -1372,9 +1398,9 @@ name = "failure_derive"
 version = "0.1.6"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
  "synstructure 0.12.2 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -1594,6 +1620,14 @@ name = "hash-db"
 version = "0.11.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 
+[[package]]
+name = "hash256-std-hasher"
+version = "0.11.0"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "crunchy 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "heapsize"
 version = "0.4.2"
@@ -1751,12 +1785,12 @@ dependencies = [
  "time 0.1.42 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio 0.1.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-buf 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-tcp 0.1.3 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-threadpool 0.1.16 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-timer 0.2.11 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-threadpool 0.1.18 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-timer 0.2.13 (registry+https://github.com/rust-lang/crates.io-index)",
  "want 0.2.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -1905,7 +1939,7 @@ dependencies = [
  "kvdb 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "kvdb-memorydb 0.1.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "memory-db 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "memory-db 0.11.0",
  "parity-bytes 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "parking_lot 0.7.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "rlp 0.3.0 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -1929,9 +1963,9 @@ version = "14.0.3"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "proc-macro-crate 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)",
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -2031,6 +2065,16 @@ dependencies = [
  "tiny-keccak 1.5.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "keccak-hasher"
+version = "0.11.0"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "hash-db 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "hash256-std-hasher 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tiny-keccak 1.5.0 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "kernel32-sys"
 version = "0.2.2"
@@ -2239,6 +2283,16 @@ dependencies = [
  "lru-cache 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "memory-db"
+version = "0.11.0"
+dependencies = [
+ "criterion 0.2.11 (registry+https://github.com/rust-lang/crates.io-index)",
+ "hash-db 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "heapsize 0.4.2 (git+https://github.com/cheme/heapsize.git?branch=ec-macfix)",
+ "keccak-hasher 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "memory-db"
 version = "0.11.0"
@@ -2275,9 +2329,10 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
 name = "mio"
-version = "0.6.19"
+version = "0.6.22"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
+ "cfg-if 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
  "fuchsia-zircon 0.3.3 (registry+https://github.com/rust-lang/crates.io-index)",
  "fuchsia-zircon-sys 0.3.3 (registry+https://github.com/rust-lang/crates.io-index)",
  "iovec 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2297,7 +2352,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "lazycell 1.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "slab 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -2307,7 +2362,7 @@ version = "0.1.6"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "miow 0.3.3 (registry+https://github.com/rust-lang/crates.io-index)",
  "winapi 0.3.8 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -2319,7 +2374,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "iovec 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.65 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -2561,7 +2616,7 @@ dependencies = [
  "failure 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.65 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -2596,6 +2651,7 @@ dependencies = [
  "fdlimit 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "fetch 0.1.0",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
+ "hyper 0.12.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "ipnetwork 0.12.8 (registry+https://github.com/rust-lang/crates.io-index)",
  "journaldb 0.2.0",
  "jsonrpc-core 14.0.3 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2618,6 +2674,7 @@ dependencies = [
  "parity-version 2.5.13",
  "parking_lot 0.7.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "pretty_assertions 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "prometheus 0.9.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "regex 1.3.9 (registry+https://github.com/rust-lang/crates.io-index)",
  "registrar 0.0.1",
  "rlp 0.3.0 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2628,6 +2685,7 @@ dependencies = [
  "serde 1.0.102 (registry+https://github.com/rust-lang/crates.io-index)",
  "serde_derive 1.0.102 (registry+https://github.com/rust-lang/crates.io-index)",
  "serde_json 1.0.41 (registry+https://github.com/rust-lang/crates.io-index)",
+ "stats 0.1.0",
  "tempdir 0.3.7 (registry+https://github.com/rust-lang/crates.io-index)",
  "term_size 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "textwrap 0.9.0 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -3041,9 +3099,9 @@ name = "proc-macro-hack"
 version = "0.5.11"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3056,12 +3114,30 @@ dependencies = [
 
 [[package]]
 name = "proc-macro2"
-version = "1.0.6"
+version = "1.0.19"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "unicode-xid 0.2.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "prometheus"
+version = "0.9.0"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "cfg-if 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "fnv 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "lazy_static 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "protobuf 2.16.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "spin 0.5.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "thiserror 1.0.20 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
+[[package]]
+name = "protobuf"
+version = "2.16.2"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+
 [[package]]
 name = "pulldown-cmark"
 version = "0.0.3"
@@ -3114,7 +3190,7 @@ name = "quote"
 version = "1.0.2"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3640,9 +3716,9 @@ name = "serde_derive"
 version = "1.0.102"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3776,6 +3852,7 @@ name = "stats"
 version = "0.1.0"
 dependencies = [
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "prometheus 0.9.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -3826,10 +3903,10 @@ dependencies = [
 
 [[package]]
 name = "syn"
-version = "1.0.5"
+version = "1.0.38"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "unicode-xid 0.2.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -3850,9 +3927,9 @@ name = "synstructure"
 version = "0.12.2"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
  "unicode-xid 0.2.0 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -3917,6 +3994,24 @@ dependencies = [
  "unicode-width 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
+[[package]]
+name = "thiserror"
+version = "1.0.20"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "thiserror-impl 1.0.20 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
+[[package]]
+name = "thiserror-impl"
+version = "1.0.20"
+source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "quote 1.0.2 (registry+https://github.com/rust-lang/crates.io-index)",
+ "syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)",
+]
+
 [[package]]
 name = "thread-id"
 version = "3.3.0"
@@ -3997,18 +4092,18 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "bytes 0.4.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "num_cpus 1.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-codec 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-current-thread 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-fs 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-sync 0.1.7 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-tcp 0.1.3 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-threadpool 0.1.16 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-timer 0.2.11 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-threadpool 0.1.18 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-timer 0.2.13 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-udp 0.1.5 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-uds 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -4042,13 +4137,13 @@ dependencies = [
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "iovec 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "scoped-tls 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio 0.1.22 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-timer 0.2.11 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-timer 0.2.13 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -4057,15 +4152,15 @@ version = "0.1.6"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
 name = "tokio-executor"
-version = "0.1.8"
+version = "0.1.10"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "crossbeam-utils 0.6.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "crossbeam-utils 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
@@ -4076,7 +4171,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-threadpool 0.1.16 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-threadpool 0.1.18 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -4096,25 +4191,25 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "bytes 0.4.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio-named-pipes 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio 0.1.22 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
 name = "tokio-reactor"
-version = "0.1.10"
+version = "0.1.12"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "crossbeam-utils 0.6.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "crossbeam-utils 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "lazy_static 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "num_cpus 1.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "parking_lot 0.9.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "slab 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-sync 0.1.7 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -4166,25 +4261,25 @@ dependencies = [
  "bytes 0.4.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "iovec 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
 name = "tokio-threadpool"
-version = "0.1.16"
+version = "0.1.18"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "crossbeam-deque 0.7.1 (registry+https://github.com/rust-lang/crates.io-index)",
- "crossbeam-queue 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "crossbeam-utils 0.6.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "crossbeam-queue 0.2.3 (registry+https://github.com/rust-lang/crates.io-index)",
+ "crossbeam-utils 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "lazy_static 1.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
  "num_cpus 1.11.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "slab 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -4198,13 +4293,13 @@ dependencies = [
 
 [[package]]
 name = "tokio-timer"
-version = "0.2.11"
+version = "0.2.13"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
- "crossbeam-utils 0.6.6 (registry+https://github.com/rust-lang/crates.io-index)",
+ "crossbeam-utils 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "slab 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -4215,10 +4310,10 @@ dependencies = [
  "bytes 0.4.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "futures 0.1.29 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-codec 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -4231,11 +4326,11 @@ dependencies = [
  "iovec 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.65 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio-uds 0.6.7 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-codec 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
- "tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)",
+ "tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
 
 [[package]]
@@ -4631,7 +4726,7 @@ dependencies = [
  "bytes 0.4.12 (registry+https://github.com/rust-lang/crates.io-index)",
  "httparse 1.3.4 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
- "mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)",
+ "mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "mio-extras 2.0.5 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "sha-1 0.8.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -4703,6 +4798,7 @@ dependencies = [
 "checksum assert_matches 1.3.0 (registry+https://github.com/rust-lang/crates.io-index)" = "7deb0a829ca7bcfaf5da70b073a8d128619259a7be8216a355e23f00763059e5"
 "checksum atty 0.2.13 (registry+https://github.com/rust-lang/crates.io-index)" = "1803c647a3ec87095e7ae7acfca019e98de5ec9a7d01343f611cf3152ed71a90"
 "checksum autocfg 0.1.7 (registry+https://github.com/rust-lang/crates.io-index)" = "1d49d90015b3c36167a20fe2810c5cd875ad504b39cff3d4eae7977e6b7c1cb2"
+"checksum autocfg 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "f8aac770f1885fd7e387acedd76065302551364496e46b3dd00860b2f8359b9d"
 "checksum backtrace 0.3.40 (registry+https://github.com/rust-lang/crates.io-index)" = "924c76597f0d9ca25d762c25a4d369d51267536465dc5064bdf0eb073ed477ea"
 "checksum backtrace-sys 0.1.32 (registry+https://github.com/rust-lang/crates.io-index)" = "5d6575f128516de27e3ce99689419835fce9643a9b215a14d2b5b685be018491"
 "checksum base64 0.10.1 (registry+https://github.com/rust-lang/crates.io-index)" = "0b25d992356d2eb0ed82172f5248873db5560c4721f564b13cb5193bda5e668e"
@@ -4739,7 +4835,9 @@ dependencies = [
 "checksum crossbeam-deque 0.7.1 (registry+https://github.com/rust-lang/crates.io-index)" = "b18cd2e169ad86297e6bc0ad9aa679aee9daa4f19e8163860faf7c164e4f5a71"
 "checksum crossbeam-epoch 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)" = "fedcd6772e37f3da2a9af9bf12ebe046c0dfe657992377b4df982a2b54cd37a9"
 "checksum crossbeam-queue 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "7c979cd6cfe72335896575c6b5688da489e420d36a27a0b9eb0c73db574b4a4b"
+"checksum crossbeam-queue 0.2.3 (registry+https://github.com/rust-lang/crates.io-index)" = "774ba60a54c213d409d5353bda12d49cd68d14e45036a285234c8d6f91f92570"
 "checksum crossbeam-utils 0.6.6 (registry+https://github.com/rust-lang/crates.io-index)" = "04973fa96e96579258a5091af6003abde64af786b860f18622b82e026cca60e6"
+"checksum crossbeam-utils 0.7.2 (registry+https://github.com/rust-lang/crates.io-index)" = "c3c7c73a2d1e9fc0886a08b93e98eb643461230d5f1925e4036204d5f2e261a8"
 "checksum crunchy 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "a2f4a431c5c9f662e1200b7c7f02c34e91361150e382089a8f2dec3ba680cbda"
 "checksum crunchy 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)" = "7a81dae078cea95a014a339291cec439d2f232ebe854a9d672b796c6afafa9b7"
 "checksum crypto-mac 0.6.2 (registry+https://github.com/rust-lang/crates.io-index)" = "7afa06d05a046c7a47c3a849907ec303504608c927f4e85f7bfff22b7180d971"
@@ -4795,6 +4893,7 @@ dependencies = [
 "checksum h2 0.1.26 (registry+https://github.com/rust-lang/crates.io-index)" = "a5b34c246847f938a410a03c5458c7fee2274436675e76d8b903c08efc29c462"
 "checksum hamming 0.1.3 (registry+https://github.com/rust-lang/crates.io-index)" = "65043da274378d68241eb9a8f8f8aa54e349136f7b8e12f63e3ef44043cc30e1"
 "checksum hash-db 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)" = "1b03501f6e1a2a97f1618879aba3156f14ca2847faa530c4e28859638bd11483"
+"checksum hash256-std-hasher 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)" = "f5c13dbac3cc50684760f54af18545c9e80fb75e93a3e586d71ebdc13138f6a4"
 "checksum heapsize 0.4.2 (git+https://github.com/cheme/heapsize.git?branch=ec-macfix)" = "<none>"
 "checksum heck 0.3.1 (registry+https://github.com/rust-lang/crates.io-index)" = "20564e78d53d2bb135c343b3f47714a56af2061f1c928fdb541dc7b9fdd94205"
 "checksum hermit-abi 0.1.3 (registry+https://github.com/rust-lang/crates.io-index)" = "307c3c9f937f38e3534b1d6447ecf090cafcc9744e4a6360e8b037b2cf5af120"
@@ -4834,6 +4933,7 @@ dependencies = [
 "checksum jsonrpc-tcp-server 14.0.3 (registry+https://github.com/rust-lang/crates.io-index)" = "9c7807563cd721401285b59b54358f5b2325b4de6ff6f1de5494a5879e890fc1"
 "checksum jsonrpc-ws-server 14.0.3 (registry+https://github.com/rust-lang/crates.io-index)" = "af36a129cef77a9db8028ac7552d927e1bb7b6928cd96b23dd25cc38bff974ab"
 "checksum keccak-hash 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "253bbe643c32c816bf58fa5a88248fafedeebb139705ad17a62add3517854a86"
+"checksum keccak-hasher 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)" = "cb9d3670023f4c04153d90b8a557a822d1b27ed702bb015a87cf7bffead5b611"
 "checksum kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)" = "7507624b29483431c0ba2d82aece8ca6cdba9382bff4ddd0f7490560c056098d"
 "checksum kvdb 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "c1b2f251f01a7224426abdb2563707d856f7de995d821744fd8fa8e2874f69e3"
 "checksum kvdb-memorydb 0.1.0 (registry+https://github.com/rust-lang/crates.io-index)" = "45bcdf5eb083602cff61a6f8438dce2a7900d714e893fc48781c39fb119d37aa"
@@ -4861,7 +4961,7 @@ dependencies = [
 "checksum memory-db 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)" = "94da53143d45f6bad3753f532e56ad57a6a26c0ca6881794583310c7cb4c885f"
 "checksum memory_units 0.3.0 (registry+https://github.com/rust-lang/crates.io-index)" = "71d96e3f3c0b6325d8ccd83c33b28acb183edcb6c67938ba104ec546854b0882"
 "checksum mime 0.3.14 (registry+https://github.com/rust-lang/crates.io-index)" = "dd1d63acd1b78403cc0c325605908475dd9b9a3acbf65ed8bcab97e27014afcf"
-"checksum mio 0.6.19 (registry+https://github.com/rust-lang/crates.io-index)" = "83f51996a3ed004ef184e16818edc51fadffe8e7ca68be67f9dee67d84d0ff23"
+"checksum mio 0.6.22 (registry+https://github.com/rust-lang/crates.io-index)" = "fce347092656428bc8eaf6201042cb551b8d67855af7374542a92a0fbfcac430"
 "checksum mio-extras 2.0.5 (registry+https://github.com/rust-lang/crates.io-index)" = "46e73a04c2fa6250b8d802134d56d554a9ec2922bf977777c805ea5def61ce40"
 "checksum mio-named-pipes 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "f5e374eff525ce1c5b7687c4cef63943e7686524a387933ad27ca7ec43779cb3"
 "checksum mio-uds 0.6.7 (registry+https://github.com/rust-lang/crates.io-index)" = "966257a94e196b11bb43aca423754d87429960a768de9414f3691d6957abf125"
@@ -4919,7 +5019,9 @@ dependencies = [
 "checksum proc-macro-crate 0.1.4 (registry+https://github.com/rust-lang/crates.io-index)" = "e10d4b51f154c8a7fb96fd6dad097cb74b863943ec010ac94b9fd1be8861fe1e"
 "checksum proc-macro-hack 0.5.11 (registry+https://github.com/rust-lang/crates.io-index)" = "ecd45702f76d6d3c75a80564378ae228a85f0b59d2f3ed43c91b4a69eb2ebfc5"
 "checksum proc-macro2 0.4.30 (registry+https://github.com/rust-lang/crates.io-index)" = "cf3d2011ab5c909338f7887f4fc896d35932e29146c12c8d01da6b22a80ba759"
-"checksum proc-macro2 1.0.6 (registry+https://github.com/rust-lang/crates.io-index)" = "9c9e470a8dc4aeae2dee2f335e8f533e2d4b347e1434e5671afc49b054592f27"
+"checksum proc-macro2 1.0.19 (registry+https://github.com/rust-lang/crates.io-index)" = "04f5f085b5d71e2188cb8271e5da0161ad52c3f227a661a3c135fdf28e258b12"
+"checksum prometheus 0.9.0 (registry+https://github.com/rust-lang/crates.io-index)" = "dd0ced56dee39a6e960c15c74dc48849d614586db2eaada6497477af7c7811cd"
+"checksum protobuf 2.16.2 (registry+https://github.com/rust-lang/crates.io-index)" = "d883f78645c21b7281d21305181aa1f4dd9e9363e7cf2566c93121552cff003e"
 "checksum pulldown-cmark 0.0.3 (registry+https://github.com/rust-lang/crates.io-index)" = "8361e81576d2e02643b04950e487ec172b687180da65c731c03cf336784e6c07"
 "checksum pwasm-utils 0.6.2 (registry+https://github.com/rust-lang/crates.io-index)" = "efb0dcbddbb600f47a7098d33762a00552c671992171637f5bb310b37fe1f0e4"
 "checksum quick-error 1.2.2 (registry+https://github.com/rust-lang/crates.io-index)" = "9274b940887ce9addde99c4eee6b5c44cc494b182b97e73dc8ffdcb3397fd3f0"
@@ -5005,7 +5107,7 @@ dependencies = [
 "checksum subtle 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)" = "2d67a5a62ba6e01cb2192ff309324cb4875d0c451d55fe2319433abe7a05a8ee"
 "checksum subtle 2.1.0 (registry+https://github.com/rust-lang/crates.io-index)" = "01dca13cf6c3b179864ab3292bd794e757618d35a7766b7c46050c614ba00829"
 "checksum syn 0.15.26 (registry+https://github.com/rust-lang/crates.io-index)" = "f92e629aa1d9c827b2bb8297046c1ccffc57c99b947a680d3ccff1f136a3bee9"
-"checksum syn 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)" = "66850e97125af79138385e9b88339cbcd037e3f28ceab8c5ad98e64f0f1f80bf"
+"checksum syn 1.0.38 (registry+https://github.com/rust-lang/crates.io-index)" = "e69abc24912995b3038597a7a593be5053eb0fb44f3cc5beec0deb421790c1f4"
 "checksum synstructure 0.10.1 (registry+https://github.com/rust-lang/crates.io-index)" = "73687139bf99285483c96ac0add482c3776528beac1d97d444f6e91f203a2015"
 "checksum synstructure 0.12.2 (registry+https://github.com/rust-lang/crates.io-index)" = "575be94ccb86e8da37efb894a87e2b660be299b41d8ef347f9d6d79fbe61b1ba"
 "checksum target_info 0.1.0 (registry+https://github.com/rust-lang/crates.io-index)" = "c63f48baada5c52e65a29eef93ab4f8982681b67f9e8d29c7b05abcfec2b9ffe"
@@ -5015,6 +5117,8 @@ dependencies = [
 "checksum termcolor 1.0.5 (registry+https://github.com/rust-lang/crates.io-index)" = "96d6098003bde162e4277c70665bd87c326f5a0c3f3fbfb285787fa482d54e6e"
 "checksum textwrap 0.11.0 (registry+https://github.com/rust-lang/crates.io-index)" = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060"
 "checksum textwrap 0.9.0 (registry+https://github.com/rust-lang/crates.io-index)" = "c0b59b6b4b44d867f1370ef1bd91bfb262bf07bf0ae65c202ea2fbc16153b693"
+"checksum thiserror 1.0.20 (registry+https://github.com/rust-lang/crates.io-index)" = "7dfdd070ccd8ccb78f4ad66bf1982dc37f620ef696c6b5028fe2ed83dd3d0d08"
+"checksum thiserror-impl 1.0.20 (registry+https://github.com/rust-lang/crates.io-index)" = "bd80fc12f73063ac132ac92aceea36734f04a1d93c1240c6944e23a3b8841793"
 "checksum thread-id 3.3.0 (registry+https://github.com/rust-lang/crates.io-index)" = "c7fbf4c9d56b320106cd64fd024dadfa0be7cb4706725fc44a7d7ce952d820c1"
 "checksum thread_local 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)" = "c6b53e329000edc2b34dbe8545fd20e55a333362d0a321909685a19bd28c3f1b"
 "checksum thread_local 1.0.1 (registry+https://github.com/rust-lang/crates.io-index)" = "d40c6d1b69745a6ec6fb1ca717914848da4b44ae29d9b3080cbee91d72a69b14"
@@ -5028,19 +5132,19 @@ dependencies = [
 "checksum tokio-codec 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "5c501eceaf96f0e1793cf26beb63da3d11c738c4a943fdf3746d81d64684c39f"
 "checksum tokio-core 0.1.17 (registry+https://github.com/rust-lang/crates.io-index)" = "aeeffbbb94209023feaef3c196a41cbcdafa06b4a6f893f68779bb5e53796f71"
 "checksum tokio-current-thread 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "d16217cad7f1b840c5a97dfb3c43b0c871fef423a6e8d2118c604e843662a443"
-"checksum tokio-executor 0.1.8 (registry+https://github.com/rust-lang/crates.io-index)" = "0f27ee0e6db01c5f0b2973824547ce7e637b2ed79b891a9677b0de9bd532b6ac"
+"checksum tokio-executor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)" = "fb2d1b8f4548dbf5e1f7818512e9c406860678f29c300cdf0ebac72d1a3a1671"
 "checksum tokio-fs 0.1.6 (registry+https://github.com/rust-lang/crates.io-index)" = "3fe6dc22b08d6993916647d108a1a7d15b9cd29c4f4496c62b92c45b5041b7af"
 "checksum tokio-io 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)" = "5090db468dad16e1a7a54c8c67280c5e4b544f3d3e018f0b913b400261f85926"
 "checksum tokio-named-pipes 0.1.0 (registry+https://github.com/rust-lang/crates.io-index)" = "9d282d483052288b2308ba5ee795f5673b159c9bdf63c385a05609da782a5eae"
-"checksum tokio-reactor 0.1.10 (registry+https://github.com/rust-lang/crates.io-index)" = "c56391be9805bc80163151c0b9e5164ee64f4b0200962c346fea12773158f22d"
+"checksum tokio-reactor 0.1.12 (registry+https://github.com/rust-lang/crates.io-index)" = "09bc590ec4ba8ba87652da2068d150dcada2cfa2e07faae270a5e0409aa51351"
 "checksum tokio-retry 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)" = "f05746ae87dca83a2016b4f5dba5b237b897dd12fd324f60afe282112f16969a"
 "checksum tokio-rustls 0.9.4 (registry+https://github.com/rust-lang/crates.io-index)" = "95a199832a67452c60bed18ed951d28d5755ff57b02b3d2d535d9f13a81ea6c9"
 "checksum tokio-service 0.1.0 (registry+https://github.com/rust-lang/crates.io-index)" = "24da22d077e0f15f55162bdbdc661228c1581892f52074fb242678d015b45162"
 "checksum tokio-sync 0.1.7 (registry+https://github.com/rust-lang/crates.io-index)" = "d06554cce1ae4a50f42fba8023918afa931413aded705b560e29600ccf7c6d76"
 "checksum tokio-tcp 0.1.3 (registry+https://github.com/rust-lang/crates.io-index)" = "1d14b10654be682ac43efee27401d792507e30fd8d26389e1da3b185de2e4119"
-"checksum tokio-threadpool 0.1.16 (registry+https://github.com/rust-lang/crates.io-index)" = "2bd2c6a3885302581f4401c82af70d792bb9df1700e7437b0aeb4ada94d5388c"
+"checksum tokio-threadpool 0.1.18 (registry+https://github.com/rust-lang/crates.io-index)" = "df720b6581784c118f0eb4310796b12b1d242a7eb95f716a8367855325c25f89"
 "checksum tokio-timer 0.1.2 (registry+https://github.com/rust-lang/crates.io-index)" = "6131e780037787ff1b3f8aad9da83bca02438b72277850dd6ad0d455e0e20efc"
-"checksum tokio-timer 0.2.11 (registry+https://github.com/rust-lang/crates.io-index)" = "f2106812d500ed25a4f38235b9cae8f78a09edf43203e16e59c3b769a342a60e"
+"checksum tokio-timer 0.2.13 (registry+https://github.com/rust-lang/crates.io-index)" = "93044f2d313c95ff1cb7809ce9a7a05735b012288a888b62d4434fd58c94f296"
 "checksum tokio-udp 0.1.5 (registry+https://github.com/rust-lang/crates.io-index)" = "f02298505547f73e60f568359ef0d016d5acd6e830ab9bc7c4a5b3403440121b"
 "checksum tokio-uds 0.2.5 (registry+https://github.com/rust-lang/crates.io-index)" = "037ffc3ba0e12a0ab4aca92e5234e0dedeb48fddf6ccd260f1f150a36a9f2445"
 "checksum toml 0.4.10 (registry+https://github.com/rust-lang/crates.io-index)" = "758664fc71a3a69038656bee8b6be6477d2a6c315a6b81f7081f591bffa4111f"
diff --git a/Cargo.toml b/Cargo.toml
index c0c138bfb..bf64c308b 100644
--- a/Cargo.toml
+++ b/Cargo.toml
@@ -27,6 +27,7 @@ serde = "1.0"
 serde_json = "1.0"
 serde_derive = "1.0"
 futures = "0.1"
+hyper = { version = "0.12" }
 fdlimit = "0.1"
 ctrlc = { git = "https://github.com/paritytech/rust-ctrlc.git" }
 jsonrpc-core = "14.0.0"
@@ -63,6 +64,8 @@ migration-rocksdb = { path = "util/migration-rocksdb" }
 kvdb = "0.1"
 kvdb-rocksdb = "0.1.3"
 journaldb = { path = "util/journaldb" }
+stats = { path = "util/stats" }
+prometheus = "0.9.0"
 
 ethcore-secretstore = { path = "secret-store", optional = true }
 
diff --git a/ethcore/Cargo.toml b/ethcore/Cargo.toml
index 202e36761..6459b4a4b 100644
--- a/ethcore/Cargo.toml
+++ b/ethcore/Cargo.toml
@@ -47,7 +47,7 @@ log = "0.4"
 lru-cache = "0.1"
 macros = { path = "../util/macros" }
 memory-cache = { path = "../util/memory-cache" }
-memory-db = "0.11"
+memory-db = { path = "../util/memory-db" }
 num_cpus = "1.2"
 parity-bytes = "0.1"
 parity-snappy = "0.1"
diff --git a/ethcore/service/src/service.rs b/ethcore/service/src/service.rs
index ed2d36f51..e5af70cf7 100644
--- a/ethcore/service/src/service.rs
+++ b/ethcore/service/src/service.rs
@@ -171,7 +171,7 @@ impl IoHandler<ClientIoMessage> for ClientIoHandler {
             CLIENT_TICK_TIMER => {
                 use ethcore::snapshot::SnapshotService;
                 let snapshot_restoration =
-                    if let RestorationStatus::Ongoing { .. } = self.snapshot.status() {
+                    if let RestorationStatus::Ongoing { .. } = self.snapshot.restoration_status() {
                         true
                     } else {
                         false
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 98f833c25..96cad76ed 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -85,6 +85,7 @@ use snapshot::{self, io as snapshot_io, SnapshotClient};
 use spec::Spec;
 use state::{self, State};
 use state_db::StateDB;
+use stats::{prometheus, prometheus_counter, prometheus_gauge, PrometheusMetrics};
 use trace::{
     self, Database as TraceDatabase, ImportRequest as TraceImportRequest, LocalizedTrace, TraceDB,
 };
@@ -118,8 +119,8 @@ pub struct ClientReport {
     pub transactions_applied: usize,
     /// How much gas has been processed so far.
     pub gas_processed: U256,
-    /// Memory used by state DB
-    pub state_db_mem: usize,
+    /// Internal structure item sizes
+    pub item_sizes: BTreeMap<String, usize>,
 }
 
 impl ClientReport {
@@ -135,13 +136,9 @@ impl<'a> ::std::ops::Sub<&'a ClientReport> for ClientReport {
     type Output = Self;
 
     fn sub(mut self, other: &'a ClientReport) -> Self {
-        let higher_mem = ::std::cmp::max(self.state_db_mem, other.state_db_mem);
-        let lower_mem = ::std::cmp::min(self.state_db_mem, other.state_db_mem);
-
         self.blocks_imported -= other.blocks_imported;
         self.transactions_applied -= other.transactions_applied;
         self.gas_processed = self.gas_processed - other.gas_processed;
-        self.state_db_mem = higher_mem - lower_mem;
 
         self
     }
@@ -1245,7 +1242,7 @@ impl Client {
     /// Get the report.
     pub fn report(&self) -> ClientReport {
         let mut report = self.report.read().clone();
-        report.state_db_mem = self.state_db.read().mem_used();
+        self.state_db.read().get_sizes(&mut report.item_sizes);
         report
     }
 
@@ -3183,6 +3180,163 @@ impl IoChannelQueue {
     }
 }
 
+impl PrometheusMetrics for Client {
+    fn prometheus_metrics(&self, r: &mut prometheus::Registry) {
+        // gas, tx & blocks
+        let report = self.report();
+
+        for (key, value) in report.item_sizes.iter() {
+            prometheus_gauge(
+                r,
+                &key,
+                format!("Total item number of {}", key).as_str(),
+                *value as i64,
+            );
+        }
+
+        prometheus_counter(
+            r,
+            "import_gas",
+            "Gas processed",
+            report.gas_processed.as_u64() as i64,
+        );
+        prometheus_counter(
+            r,
+            "import_blocks",
+            "Blocks imported",
+            report.blocks_imported as i64,
+        );
+        prometheus_counter(
+            r,
+            "import_txs",
+            "Transactions applied",
+            report.transactions_applied as i64,
+        );
+
+        let state_db = self.state_db.read();
+        prometheus_gauge(
+            r,
+            "statedb_cache_size",
+            "State DB cache size",
+            state_db.cache_size() as i64,
+        );
+
+        // blockchain cache
+        let blockchain_cache_info = self.blockchain_cache_info();
+        prometheus_gauge(
+            r,
+            "blockchaincache_block_details",
+            "BlockDetails cache size",
+            blockchain_cache_info.block_details as i64,
+        );
+        prometheus_gauge(
+            r,
+            "blockchaincache_block_recipts",
+            "Block receipts size",
+            blockchain_cache_info.block_receipts as i64,
+        );
+        prometheus_gauge(
+            r,
+            "blockchaincache_blocks",
+            "Blocks cache size",
+            blockchain_cache_info.blocks as i64,
+        );
+        prometheus_gauge(
+            r,
+            "blockchaincache_txaddrs",
+            "Transaction addresses cache size",
+            blockchain_cache_info.transaction_addresses as i64,
+        );
+        prometheus_gauge(
+            r,
+            "blockchaincache_size",
+            "Total blockchain cache size",
+            blockchain_cache_info.total() as i64,
+        );
+
+        // chain info
+        let chain = self.chain_info();
+
+        let gap = chain
+            .ancient_block_number
+            .map(|x| U256::from(x + 1))
+            .and_then(|first| {
+                chain
+                    .first_block_number
+                    .map(|last| (first, U256::from(last)))
+            });
+        if let Some((first, last)) = gap {
+            prometheus_gauge(
+                r,
+                "chain_warpsync_gap_first",
+                "Warp sync gap, first block",
+                first.as_u64() as i64,
+            );
+            prometheus_gauge(
+                r,
+                "chain_warpsync_gap_last",
+                "Warp sync gap, last block",
+                last.as_u64() as i64,
+            );
+        }
+
+        prometheus_gauge(
+            r,
+            "chain_block",
+            "Best block number",
+            chain.best_block_number as i64,
+        );
+
+        // prunning info
+        let prunning = self.pruning_info();
+        prometheus_gauge(
+            r,
+            "prunning_earliest_chain",
+            "The first block which everything can be served after",
+            prunning.earliest_chain as i64,
+        );
+        prometheus_gauge(
+            r,
+            "prunning_earliest_state",
+            "The first block where state requests may be served",
+            prunning.earliest_state as i64,
+        );
+
+        // queue info
+        let queue = self.queue_info();
+        prometheus_gauge(
+            r,
+            "queue_mem_used",
+            "Queue heap memory used in bytes",
+            queue.mem_used as i64,
+        );
+        prometheus_gauge(
+            r,
+            "queue_size_total",
+            "The total size of the queues",
+            queue.total_queue_size() as i64,
+        );
+        prometheus_gauge(
+            r,
+            "queue_size_unverified",
+            "Number of queued items pending verification",
+            queue.unverified_queue_size as i64,
+        );
+        prometheus_gauge(
+            r,
+            "queue_size_verified",
+            "Number of verified queued items pending import",
+            queue.verified_queue_size as i64,
+        );
+        prometheus_gauge(
+            r,
+            "queue_size_verifying",
+            "Number of items being verified",
+            queue.verifying_queue_size as i64,
+        );
+    }
+}
+
 #[cfg(test)]
 mod tests {
     use blockchain::{BlockProvider, ExtrasInsert};
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index 0059dc3ce..898fed8a7 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -72,6 +72,7 @@ use miner::{self, Miner, MinerService};
 use spec::Spec;
 use state::StateInfo;
 use state_db::StateDB;
+use stats::{prometheus, PrometheusMetrics};
 use trace::LocalizedTrace;
 use verification::queue::{kind::blocks::Unverified, QueueInfo};
 
@@ -1114,3 +1115,7 @@ impl super::traits::EngineClient for TestBlockChainClient {
         BlockChainClient::block_header(self, id)
     }
 }
+
+impl PrometheusMetrics for TestBlockChainClient {
+    fn prometheus_metrics(&self, _r: &mut prometheus::Registry) {}
+}
diff --git a/ethcore/src/snapshot/mod.rs b/ethcore/src/snapshot/mod.rs
index b32b8a40f..6391c4466 100644
--- a/ethcore/src/snapshot/mod.rs
+++ b/ethcore/src/snapshot/mod.rs
@@ -64,8 +64,8 @@ pub use self::{
     watcher::Watcher,
 };
 pub use types::{
-    basic_account::BasicAccount, restoration_status::RestorationStatus,
-    snapshot_manifest::ManifestData,
+    basic_account::BasicAccount, creation_status::CreationStatus,
+    restoration_status::RestorationStatus, snapshot_manifest::ManifestData,
 };
 
 pub mod io;
diff --git a/ethcore/src/snapshot/service.rs b/ethcore/src/snapshot/service.rs
index 46acf9474..fbeedbd50 100644
--- a/ethcore/src/snapshot/service.rs
+++ b/ethcore/src/snapshot/service.rs
@@ -30,7 +30,8 @@ use std::{
 
 use super::{
     io::{LooseReader, LooseWriter, SnapshotReader, SnapshotWriter},
-    ManifestData, Rebuilder, RestorationStatus, SnapshotService, StateRebuilder, MAX_CHUNK_SIZE,
+    CreationStatus, ManifestData, Rebuilder, RestorationStatus, SnapshotService, StateRebuilder,
+    MAX_CHUNK_SIZE,
 };
 
 use blockchain::{BlockChain, BlockChainDB, BlockChainDBHandler};
@@ -271,6 +272,7 @@ pub struct Service {
     client: Arc<dyn SnapshotClient>,
     progress: super::Progress,
     taking_snapshot: AtomicBool,
+    taking_snapshot_at: AtomicUsize,
     restoring_snapshot: AtomicBool,
 }
 
@@ -292,6 +294,7 @@ impl Service {
             client: params.client,
             progress: Default::default(),
             taking_snapshot: AtomicBool::new(false),
+            taking_snapshot_at: AtomicUsize::new(0),
             restoring_snapshot: AtomicBool::new(false),
         };
 
@@ -522,6 +525,9 @@ impl Service {
             return Ok(());
         }
 
+        self.taking_snapshot_at
+            .store(num as usize, Ordering::SeqCst);
+
         info!("Taking snapshot at #{}", num);
         self.progress.reset();
 
@@ -629,6 +635,7 @@ impl Service {
 
         self.restoring_snapshot.store(true, Ordering::SeqCst);
 
+        let block_number = manifest.block_number;
         // Import previous chunks, continue if it fails
         self.import_prev_chunks(&mut res, manifest).ok();
 
@@ -636,6 +643,7 @@ impl Service {
         let mut restoration_status = self.status.lock();
         if let RestorationStatus::Initializing { .. } = *restoration_status {
             *restoration_status = RestorationStatus::Ongoing {
+                block_number,
                 state_chunks: state_chunks as u32,
                 block_chunks: block_chunks as u32,
                 state_chunks_done: self.state_chunks.load(Ordering::SeqCst) as u32,
@@ -774,7 +782,7 @@ impl Service {
         is_state: bool,
     ) -> Result<(), Error> {
         let (result, db) = {
-            match self.status() {
+            match self.restoration_status() {
                 RestorationStatus::Inactive | RestorationStatus::Failed => {
                     trace!(target: "snapshot", "Tried to restore chunk {:x} while inactive or failed", hash);
                     return Ok(());
@@ -881,7 +889,17 @@ impl SnapshotService for Service {
         }
     }
 
-    fn status(&self) -> RestorationStatus {
+    fn creation_status(&self) -> CreationStatus {
+        if self.taking_snapshot.load(Ordering::SeqCst) {
+            CreationStatus::Ongoing {
+                block_number: self.taking_snapshot_at.load(Ordering::SeqCst) as u32,
+            }
+        } else {
+            CreationStatus::Inactive
+        }
+    }
+
+    fn restoration_status(&self) -> RestorationStatus {
         let mut cur_status = self.status.lock();
 
         match *cur_status {
@@ -1003,7 +1021,7 @@ mod tests {
 
         assert!(service.manifest().is_none());
         assert!(service.chunk(Default::default()).is_none());
-        assert_eq!(service.status(), RestorationStatus::Inactive);
+        assert_eq!(service.restoration_status(), RestorationStatus::Inactive);
 
         let manifest = ManifestData {
             version: 2,
diff --git a/ethcore/src/snapshot/tests/service.rs b/ethcore/src/snapshot/tests/service.rs
index e914731d1..b747d3b55 100644
--- a/ethcore/src/snapshot/tests/service.rs
+++ b/ethcore/src/snapshot/tests/service.rs
@@ -95,7 +95,7 @@ fn restored_is_equivalent() {
         service.feed_block_chunk(hash, &chunk);
     }
 
-    assert_eq!(service.status(), RestorationStatus::Inactive);
+    assert_eq!(service.restoration_status(), RestorationStatus::Inactive);
 
     for x in 0..NUM_BLOCKS {
         let block1 = client.block(BlockId::Number(x as u64)).unwrap();
@@ -265,7 +265,7 @@ fn keep_ancient_blocks() {
         service.feed_state_chunk(*hash, &chunk);
     }
 
-    match service.status() {
+    match service.restoration_status() {
         RestorationStatus::Inactive => (),
         RestorationStatus::Failed => panic!("Snapshot Restoration has failed."),
         RestorationStatus::Ongoing { .. } => panic!("Snapshot Restoration should be done."),
@@ -334,7 +334,7 @@ fn recover_aborted_recovery() {
         service.feed_state_chunk(*hash, &chunk);
     }
 
-    match service.status() {
+    match service.restoration_status() {
         RestorationStatus::Ongoing {
             block_chunks_done,
             state_chunks_done,
@@ -352,7 +352,7 @@ fn recover_aborted_recovery() {
     // And try again!
     service.init_restore(manifest.clone(), true).unwrap();
 
-    match service.status() {
+    match service.restoration_status() {
         RestorationStatus::Ongoing {
             block_chunks_done,
             state_chunks_done,
@@ -371,7 +371,7 @@ fn recover_aborted_recovery() {
     // And try again!
     service.init_restore(manifest.clone(), true).unwrap();
 
-    match service.status() {
+    match service.restoration_status() {
         RestorationStatus::Ongoing {
             block_chunks_done,
             state_chunks_done,
diff --git a/ethcore/src/snapshot/traits.rs b/ethcore/src/snapshot/traits.rs
index d2d6ca665..755981bea 100644
--- a/ethcore/src/snapshot/traits.rs
+++ b/ethcore/src/snapshot/traits.rs
@@ -14,7 +14,7 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity Ethereum.  If not, see <http://www.gnu.org/licenses/>.
 
-use super::{ManifestData, RestorationStatus};
+use super::{CreationStatus, ManifestData, RestorationStatus};
 use bytes::Bytes;
 use ethereum_types::H256;
 
@@ -37,7 +37,10 @@ pub trait SnapshotService: Sync + Send {
     fn chunk(&self, hash: H256) -> Option<Bytes>;
 
     /// Ask the snapshot service for the restoration status.
-    fn status(&self) -> RestorationStatus;
+    fn restoration_status(&self) -> RestorationStatus;
+
+    /// Ask the snapshot service for the creation status.
+    fn creation_status(&self) -> CreationStatus;
 
     /// Begin snapshot restoration.
     /// If restoration in-progress, this will reset it.
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 42cd0c71c..e31544d6d 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -17,7 +17,7 @@
 //! State database abstraction. For more info, see the doc for `StateDB`
 
 use std::{
-    collections::{HashSet, VecDeque},
+    collections::{BTreeMap, HashSet, VecDeque},
     io,
     sync::Arc,
 };
@@ -394,13 +394,17 @@ impl StateDB {
     }
 
     /// Heap size used.
-    pub fn mem_used(&self) -> usize {
-        // TODO: account for LRU-cache overhead; this is a close approximation.
-        self.db.mem_used() + {
-            let accounts = self.account_cache.lock().accounts.len();
-            let code_size = self.code_cache.lock().current_size();
-            code_size + accounts * ::std::mem::size_of::<Option<Account>>()
-        }
+    pub fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>) {
+        self.db.get_sizes(sizes);
+
+        sizes.insert(
+            String::from("account_cache_len"),
+            self.account_cache.lock().accounts.len(),
+        );
+        sizes.insert(
+            String::from("code_cache_size"),
+            self.code_cache.lock().current_size(),
+        );
     }
 
     /// Returns underlying `JournalDB`.
diff --git a/ethcore/sync/Cargo.toml b/ethcore/sync/Cargo.toml
index c75718488..c8a0b17e7 100644
--- a/ethcore/sync/Cargo.toml
+++ b/ethcore/sync/Cargo.toml
@@ -32,6 +32,8 @@ rand = "0.4"
 rlp = { version = "0.3.0", features = ["ethereum"] }
 trace-time = "0.1"
 triehash-ethereum = {version = "0.2", path = "../../util/triehash-ethereum" }
+stats = { path = "../../util/stats" }
+
 
 [dev-dependencies]
 env_logger = "0.5"
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 782a673c8..868f30ef8 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -30,8 +30,8 @@ use std::{
 };
 
 use chain::{
-    ChainSyncApi, SyncStatus as EthSyncStatus, ETH_PROTOCOL_VERSION_62, ETH_PROTOCOL_VERSION_63,
-    PAR_PROTOCOL_VERSION_1, PAR_PROTOCOL_VERSION_2,
+    ChainSyncApi, SyncState, SyncStatus as EthSyncStatus, ETH_PROTOCOL_VERSION_62,
+    ETH_PROTOCOL_VERSION_63, PAR_PROTOCOL_VERSION_1, PAR_PROTOCOL_VERSION_2,
 };
 use ethcore::{
     client::{BlockChainClient, ChainMessageType, ChainNotify, NewBlocks},
@@ -42,12 +42,17 @@ use ethkey::Secret;
 use io::TimerToken;
 use network::IpFilter;
 use parking_lot::{Mutex, RwLock};
+use stats::{prometheus, prometheus_counter, prometheus_gauge, PrometheusMetrics};
+
 use std::{
     net::{AddrParseError, SocketAddr},
     str::FromStr,
 };
 use sync_io::NetSyncIo;
-use types::{transaction::UnverifiedTransaction, BlockNumber};
+use types::{
+    creation_status::CreationStatus, restoration_status::RestorationStatus,
+    transaction::UnverifiedTransaction, BlockNumber,
+};
 
 /// Parity sync protocol
 pub const PAR_PROTOCOL: ProtocolId = *b"par";
@@ -120,7 +125,7 @@ impl Default for SyncConfig {
 }
 
 /// Current sync status
-pub trait SyncProvider: Send + Sync {
+pub trait SyncProvider: Send + Sync + PrometheusMetrics {
     /// Get sync status
     fn status(&self) -> EthSyncStatus;
 
@@ -311,6 +316,110 @@ impl SyncProvider for EthSync {
     }
 }
 
+impl PrometheusMetrics for EthSync {
+    fn prometheus_metrics(&self, r: &mut prometheus::Registry) {
+        let scalar = |b| if b { 1i64 } else { 0i64 };
+        let sync_status = self.status();
+
+        prometheus_gauge(r,
+			"sync_status",
+			"WaitingPeers(0), SnapshotManifest(1), SnapshotData(2), SnapshotWaiting(3), Blocks(4), Idle(5), Waiting(6), NewBlocks(7)", 
+			match self.eth_handler.sync.status().state {
+			SyncState::WaitingPeers => 0,
+			SyncState::SnapshotManifest => 1,
+			SyncState::SnapshotData => 2,
+			SyncState::SnapshotWaiting => 3,
+			SyncState::Blocks => 4,
+			SyncState::Idle => 5,
+			SyncState::Waiting => 6,
+			SyncState::NewBlocks => 7,
+        });
+
+        for (key, value) in sync_status.item_sizes.iter() {
+            prometheus_gauge(
+                r,
+                &key,
+                format!("Total item number of {}", key).as_str(),
+                *value as i64,
+            );
+        }
+
+        prometheus_gauge(
+            r,
+            "net_peers",
+            "Total number of connected peers",
+            sync_status.num_peers as i64,
+        );
+        prometheus_gauge(
+            r,
+            "net_active_peers",
+            "Total number of active peers",
+            sync_status.num_active_peers as i64,
+        );
+        prometheus_counter(
+            r,
+            "sync_blocks_recieved",
+            "Number of blocks downloaded so far",
+            sync_status.blocks_received as i64,
+        );
+        prometheus_counter(
+            r,
+            "sync_blocks_total",
+            "Total number of blocks for the sync process",
+            sync_status.blocks_total as i64,
+        );
+        prometheus_gauge(
+            r,
+            "sync_blocks_highest",
+            "Highest block number in the download queue",
+            sync_status.highest_block_number.unwrap_or(0) as i64,
+        );
+
+        prometheus_gauge(
+            r,
+            "snapshot_download_active",
+            "1 if downloading snapshots",
+            scalar(sync_status.is_snapshot_syncing()),
+        );
+        prometheus_gauge(
+            r,
+            "snapshot_download_chunks",
+            "Snapshot chunks",
+            sync_status.num_snapshot_chunks as i64,
+        );
+        prometheus_gauge(
+            r,
+            "snapshot_download_chunks_done",
+            "Snapshot chunks downloaded",
+            sync_status.snapshot_chunks_done as i64,
+        );
+
+        let restoration = self.eth_handler.snapshot_service.restoration_status();
+        let creation = self.eth_handler.snapshot_service.creation_status();
+
+        prometheus_gauge(
+            r,
+            "snapshot_create_block",
+            "First block of the current snapshot creation",
+            if let CreationStatus::Ongoing { block_number } = creation {
+                block_number as i64
+            } else {
+                0
+            },
+        );
+        prometheus_gauge(
+            r,
+            "snapshot_restore_block",
+            "First block of the current snapshot restoration",
+            if let RestorationStatus::Ongoing { block_number, .. } = restoration {
+                block_number as i64
+            } else {
+                0
+            },
+        );
+    }
+}
+
 const PEERS_TIMER: TimerToken = 0;
 const MAINTAIN_SYNC_TIMER: TimerToken = 1;
 const CONTINUE_SYNC_TIMER: TimerToken = 2;
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 76e096b82..c2ea28a5d 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -24,14 +24,13 @@ use ethcore::{
     },
 };
 use ethereum_types::H256;
-use heapsize::HeapSizeOf;
 use network::{client_version::ClientCapabilities, PeerId};
 use rlp::{self, Rlp};
 use std::cmp;
 ///
 /// Blockchain downloader
 ///
-use std::collections::{HashSet, VecDeque};
+use std::collections::{BTreeMap, HashSet, VecDeque};
 use sync_io::SyncIo;
 use types::BlockNumber;
 
@@ -218,9 +217,14 @@ impl BlockDownloader {
         self.state = State::Blocks;
     }
 
-    /// Returns used heap memory size.
-    pub fn heap_size(&self) -> usize {
-        self.blocks.heap_size() + self.round_parents.heap_size_of_children()
+    /// Returns number if items in structures
+    pub fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>) {
+        let prefix = format!("{}_", self.block_set.to_string());
+        self.blocks.get_sizes(sizes, &prefix);
+        sizes.insert(
+            format!("{}{}", prefix, "round_parents"),
+            self.round_parents.len(),
+        );
     }
 
     fn reset_to_block(&mut self, start_hash: &H256, start_number: BlockNumber) {
diff --git a/ethcore/sync/src/blocks.rs b/ethcore/sync/src/blocks.rs
index 5297070e5..95936b05c 100644
--- a/ethcore/sync/src/blocks.rs
+++ b/ethcore/sync/src/blocks.rs
@@ -21,7 +21,7 @@ use hash::{keccak, KECCAK_EMPTY_LIST_RLP, KECCAK_NULL_RLP};
 use heapsize::HeapSizeOf;
 use network;
 use rlp::{DecoderError, Rlp, RlpStream};
-use std::collections::{hash_map, HashMap, HashSet};
+use std::collections::{hash_map, BTreeMap, HashMap, HashSet};
 use triehash_ethereum::ordered_trie_root;
 use types::{header::Header as BlockHeader, transaction::UnverifiedTransaction};
 
@@ -414,14 +414,37 @@ impl BlockCollection {
         self.heads.len()
     }
 
-    /// Return used heap size.
-    pub fn heap_size(&self) -> usize {
-        self.heads.heap_size_of_children()
-            + self.blocks.heap_size_of_children()
-            + self.parents.heap_size_of_children()
-            + self.header_ids.heap_size_of_children()
-            + self.downloading_headers.heap_size_of_children()
-            + self.downloading_bodies.heap_size_of_children()
+    /// Return number of items size.
+    pub fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>, insert_prefix: &str) {
+        sizes.insert(format!("{}{}", insert_prefix, "heads"), self.heads.len());
+        sizes.insert(format!("{}{}", insert_prefix, "blocks"), self.blocks.len());
+        sizes.insert(
+            format!("{}{}", insert_prefix, "parents_len"),
+            self.parents.len(),
+        );
+        sizes.insert(
+            format!("{}{}", insert_prefix, "header_ids_len"),
+            self.header_ids.len(),
+        );
+        sizes.insert(
+            format!("{}{}", insert_prefix, "downloading_headers_len"),
+            self.downloading_headers.len(),
+        );
+        sizes.insert(
+            format!("{}{}", insert_prefix, "downloading_bodies_len"),
+            self.downloading_bodies.len(),
+        );
+
+        if self.need_receipts {
+            sizes.insert(
+                format!("{}{}", insert_prefix, "downloading_receipts_len"),
+                self.downloading_receipts.len(),
+            );
+            sizes.insert(
+                format!("{}{}", insert_prefix, "receipt_ids_len"),
+                self.receipt_ids.len(),
+            );
+        }
     }
 
     /// Check if given block hash is marked as being downloaded.
diff --git a/ethcore/sync/src/chain/handler.rs b/ethcore/sync/src/chain/handler.rs
index 87ff9ba9c..3e8fa9bdf 100644
--- a/ethcore/sync/src/chain/handler.rs
+++ b/ethcore/sync/src/chain/handler.rs
@@ -599,7 +599,7 @@ impl SyncHandler {
         }
 
         // check service status
-        let status = io.snapshot_service().status();
+        let status = io.snapshot_service().restoration_status();
         match status {
             RestorationStatus::Inactive | RestorationStatus::Failed => {
                 trace!(target: "sync", "{}: Snapshot restoration aborted", peer_id);
diff --git a/ethcore/sync/src/chain/mod.rs b/ethcore/sync/src/chain/mod.rs
index 99b237bae..5fed42cb1 100644
--- a/ethcore/sync/src/chain/mod.rs
+++ b/ethcore/sync/src/chain/mod.rs
@@ -105,7 +105,6 @@ use ethcore::{
 use ethereum_types::{H256, U256};
 use fastmap::{H256FastMap, H256FastSet};
 use hash::keccak;
-use heapsize::HeapSizeOf;
 use network::{self, client_version::ClientVersion, PeerId};
 use parking_lot::{Mutex, RwLock, RwLockWriteGuard};
 use rand::Rng;
@@ -214,7 +213,7 @@ pub enum SyncState {
 }
 
 /// Syncing status and statistics
-#[derive(Clone, Copy)]
+#[derive(Clone)]
 pub struct SyncStatus {
     /// State
     pub state: SyncState,
@@ -236,14 +235,14 @@ pub struct SyncStatus {
     pub num_peers: usize,
     /// Total number of active peers.
     pub num_active_peers: usize,
-    /// Heap memory used in bytes.
-    pub mem_used: usize,
     /// Snapshot chunks
     pub num_snapshot_chunks: usize,
     /// Snapshot chunks downloaded
     pub snapshot_chunks_done: usize,
     /// Last fully downloaded and imported ancient block number (if any).
     pub last_imported_old_block_number: Option<BlockNumber>,
+    /// Internal structure item numbers
+    pub item_sizes: BTreeMap<String, usize>,
 }
 
 impl SyncStatus {
@@ -297,6 +296,16 @@ pub enum BlockSet {
     /// Missing old blocks
     OldBlocks,
 }
+
+impl BlockSet {
+    pub fn to_string(&self) -> &'static str {
+        match *self {
+            Self::NewBlocks => "new_blocks",
+            Self::OldBlocks => "old_blocks",
+        }
+    }
+}
+
 #[derive(Clone, Eq, PartialEq)]
 pub enum ForkConfirmation {
     /// Fork block confirmation pending.
@@ -708,6 +717,12 @@ impl ChainSync {
     /// Returns synchonization status
     pub fn status(&self) -> SyncStatus {
         let last_imported_number = self.new_blocks.last_imported_block_number();
+        let mut item_sizes = BTreeMap::<String, usize>::new();
+        self.old_blocks
+            .as_ref()
+            .map_or((), |d| d.get_sizes(&mut item_sizes));
+        self.new_blocks.get_sizes(&mut item_sizes);
+
         SyncStatus {
             state: self.state.clone(),
             protocol_version: ETH_PROTOCOL_VERSION_63.0,
@@ -738,9 +753,7 @@ impl ChainSync {
                 .count(),
             num_snapshot_chunks: self.snapshot.total_chunks(),
             snapshot_chunks_done: self.snapshot.done_chunks(),
-            mem_used: self.new_blocks.heap_size()
-                + self.old_blocks.as_ref().map_or(0, |d| d.heap_size())
-                + self.peers.heap_size_of_children(),
+            item_sizes: item_sizes,
         }
     }
 
@@ -1108,7 +1121,7 @@ impl ChainSync {
 					}
 				},
 				SyncState::SnapshotData => {
-					match io.snapshot_service().status() {
+					match io.snapshot_service().restoration_status() {
 						RestorationStatus::Ongoing { state_chunks_done, block_chunks_done, .. } => {
 							// Initialize the snapshot if not already done
 							self.snapshot.initialize(io.snapshot_service());
@@ -1309,13 +1322,13 @@ impl ChainSync {
                 self.state = SyncState::Blocks;
                 self.continue_sync(io);
             }
-            SyncState::SnapshotData => match io.snapshot_service().status() {
+            SyncState::SnapshotData => match io.snapshot_service().restoration_status() {
                 RestorationStatus::Inactive | RestorationStatus::Failed => {
                     self.state = SyncState::SnapshotWaiting;
                 }
                 RestorationStatus::Initializing { .. } | RestorationStatus::Ongoing { .. } => (),
             },
-            SyncState::SnapshotWaiting => match io.snapshot_service().status() {
+            SyncState::SnapshotWaiting => match io.snapshot_service().restoration_status() {
                 RestorationStatus::Inactive => {
                     trace!(target:"sync", "Snapshot restoration is complete");
                     self.restart(io);
@@ -1541,7 +1554,7 @@ pub mod tests {
             blocks_received: 0,
             num_peers: 0,
             num_active_peers: 0,
-            mem_used: 0,
+            item_sizes: BTreeMap::new(),
             num_snapshot_chunks: 0,
             snapshot_chunks_done: 0,
             last_imported_old_block_number: None,
diff --git a/ethcore/sync/src/lib.rs b/ethcore/sync/src/lib.rs
index 0f41ff450..7d8432b8f 100644
--- a/ethcore/sync/src/lib.rs
+++ b/ethcore/sync/src/lib.rs
@@ -36,6 +36,7 @@ extern crate parity_bytes as bytes;
 extern crate parking_lot;
 extern crate rand;
 extern crate rlp;
+extern crate stats;
 extern crate triehash_ethereum;
 
 #[cfg(test)]
diff --git a/ethcore/sync/src/tests/snapshot.rs b/ethcore/sync/src/tests/snapshot.rs
index 1d4dac49e..608893626 100644
--- a/ethcore/sync/src/tests/snapshot.rs
+++ b/ethcore/sync/src/tests/snapshot.rs
@@ -18,7 +18,7 @@ use super::helpers::*;
 use bytes::Bytes;
 use ethcore::{
     client::EachBlockWith,
-    snapshot::{ManifestData, RestorationStatus, SnapshotService},
+    snapshot::{CreationStatus, ManifestData, RestorationStatus, SnapshotService},
 };
 use ethereum_types::H256;
 use hash::keccak;
@@ -101,7 +101,11 @@ impl SnapshotService for TestSnapshotService {
         self.chunks.get(&hash).cloned()
     }
 
-    fn status(&self) -> RestorationStatus {
+    fn creation_status(&self) -> CreationStatus {
+        CreationStatus::Inactive
+    }
+
+    fn restoration_status(&self) -> RestorationStatus {
         match *self.restoration_manifest.lock() {
             Some(ref manifest)
                 if self.state_restoration_chunks.lock().len() == manifest.state_hashes.len()
@@ -111,6 +115,7 @@ impl SnapshotService for TestSnapshotService {
                 RestorationStatus::Inactive
             }
             Some(ref manifest) => RestorationStatus::Ongoing {
+                block_number: 0,
                 state_chunks: manifest.state_hashes.len() as u32,
                 block_chunks: manifest.block_hashes.len() as u32,
                 state_chunks_done: self.state_restoration_chunks.lock().len() as u32,
diff --git a/ethcore/types/src/creation_status.rs b/ethcore/types/src/creation_status.rs
new file mode 100644
index 000000000..f70a145f6
--- /dev/null
+++ b/ethcore/types/src/creation_status.rs
@@ -0,0 +1,27 @@
+// Copyright 2015-2019 Parity Technologies (UK) Ltd.
+// This file is part of Parity Ethereum.
+
+// Parity Ethereum is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity Ethereum is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity Ethereum.  If not, see <http://www.gnu.org/licenses/>.
+
+/// Statuses for snapshot creation.
+#[derive(PartialEq, Eq, Clone, Copy, Debug)]
+pub enum CreationStatus {
+    /// No creation activity currently.
+    Inactive,
+    /// Snapshot creation is in progress.
+    Ongoing {
+        /// Current created snapshot.
+        block_number: u32,
+    },
+}
diff --git a/ethcore/types/src/lib.rs b/ethcore/types/src/lib.rs
index cde8a0011..9135e3316 100644
--- a/ethcore/types/src/lib.rs
+++ b/ethcore/types/src/lib.rs
@@ -59,6 +59,7 @@ pub mod block;
 pub mod block_status;
 pub mod blockchain_info;
 pub mod call_analytics;
+pub mod creation_status;
 pub mod data_format;
 pub mod encoded;
 pub mod engines;
diff --git a/ethcore/types/src/restoration_status.rs b/ethcore/types/src/restoration_status.rs
index 4f24e3957..a61c37d3e 100644
--- a/ethcore/types/src/restoration_status.rs
+++ b/ethcore/types/src/restoration_status.rs
@@ -28,6 +28,8 @@ pub enum RestorationStatus {
     },
     /// Ongoing restoration.
     Ongoing {
+        /// Block number specified in the manifest.
+        block_number: u64,
         /// Total number of state chunks.
         state_chunks: u32,
         /// Total number of block chunks.
diff --git a/parity/cli/mod.rs b/parity/cli/mod.rs
index 0aa86023f..ab80e6d99 100644
--- a/parity/cli/mod.rs
+++ b/parity/cli/mod.rs
@@ -466,6 +466,19 @@ usage! {
             "--ws-max-connections=[CONN]",
             "Maximum number of allowed concurrent WebSockets JSON-RPC connections.",
 
+        ["Metrics"]
+            FLAG flag_metrics: (bool) = false, or |c: &Config| c.metrics.as_ref()?.enable.clone(),
+            "--metrics",
+            "Enable prometheus metrics (only full client).",
+
+            ARG arg_metrics_port: (u16) = 3000u16, or |c: &Config| c.metrics.as_ref()?.port.clone(),
+            "--metrics-port=[PORT]",
+            "Specify the port portion of the metrics server.",
+
+            ARG arg_metrics_interface: (String) = "local", or |c: &Config| c.metrics.as_ref()?.interface.clone(),
+            "--metrics-interface=[IP]",
+            "Specify the hostname portion of the metrics server, IP should be an interface's IP address, or all (all interfaces) or local.",
+
         ["API and Console Options ??? IPC"]
             FLAG flag_no_ipc: (bool) = false, or |c: &Config| c.ipc.as_ref()?.disable.clone(),
             "--no-ipc",
@@ -808,6 +821,7 @@ struct Config {
     snapshots: Option<Snapshots>,
     misc: Option<Misc>,
     stratum: Option<Stratum>,
+    metrics: Option<Metrics>,
 }
 
 #[derive(Default, Debug, PartialEq, Deserialize)]
@@ -899,6 +913,14 @@ struct Ipc {
     apis: Option<Vec<String>>,
 }
 
+#[derive(Default, Debug, PartialEq, Deserialize)]
+#[serde(deny_unknown_fields)]
+struct Metrics {
+    enable: Option<bool>,
+    port: Option<u16>,
+    interface: Option<String>,
+}
+
 #[derive(Default, Debug, PartialEq, Deserialize)]
 #[serde(deny_unknown_fields)]
 struct SecretStore {
@@ -1007,8 +1029,8 @@ struct Misc {
 #[cfg(test)]
 mod tests {
     use super::{
-        Account, Args, ArgsError, Config, Footprint, Ipc, Mining, Misc, Network, Operating, Rpc,
-        SecretStore, Snapshots, Ws,
+        Account, Args, ArgsError, Config, Footprint, Ipc, Metrics, Mining, Misc, Network,
+        Operating, Rpc, SecretStore, Snapshots, Ws,
     };
     use clap::ErrorKind as ClapErrorKind;
     use toml;
@@ -1307,6 +1329,11 @@ mod tests {
                 arg_ipc_apis: "web3,eth,net,parity,parity_accounts,personal,traces,secretstore"
                     .into(),
 
+                // METRICS
+                flag_metrics: false,
+                arg_metrics_port: 3000u16,
+                arg_metrics_interface: "local".into(),
+
                 // SECRETSTORE
                 flag_no_secretstore: false,
                 flag_no_secretstore_http: false,
@@ -1505,6 +1532,11 @@ mod tests {
                     path: None,
                     apis: Some(vec!["rpc".into(), "eth".into()]),
                 }),
+                metrics: Some(Metrics {
+                    enable: Some(true),
+                    interface: Some("local".to_string()),
+                    port: Some(4000),
+                }),
                 secretstore: Some(SecretStore {
                     disable: None,
                     disable_http: None,
diff --git a/parity/cli/tests/config.toml b/parity/cli/tests/config.toml
index b3d7eb6f0..6e499e910 100644
--- a/parity/cli/tests/config.toml
+++ b/parity/cli/tests/config.toml
@@ -32,6 +32,12 @@ port = 8180
 [ipc]
 apis = ["rpc", "eth"]
 
+[metrics]
+enable = true
+interface = "local"
+port = 4000
+
+
 [secretstore]
 http_port = 8082
 port = 8083
diff --git a/parity/configuration.rs b/parity/configuration.rs
index 6ca82a32a..67854aab4 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -26,6 +26,7 @@ use ethcore::{
 use ethereum_types::{Address, H256, U256};
 use ethkey::{Public, Secret};
 use hash::keccak;
+use metrics::MetricsConfiguration;
 use miner::pool;
 use num_cpus;
 use parity_version::{version, version_data};
@@ -158,6 +159,7 @@ impl Configuration {
         let experimental_rpcs = self.args.flag_jsonrpc_experimental;
         let secretstore_conf = self.secretstore_config()?;
         let format = self.format()?;
+        let metrics_conf = self.metrics_config()?;
         let keys_iterations = NonZeroU32::new(self.args.arg_keys_iterations)
             .ok_or_else(|| "--keys-iterations must be non-zero")?;
 
@@ -422,6 +424,7 @@ impl Configuration {
                 verifier_settings: verifier_settings,
                 no_persistent_txqueue: self.args.flag_no_persistent_txqueue,
                 max_round_blocks_to_import: self.args.arg_max_round_blocks_to_import,
+                metrics_conf,
             };
             Cmd::Run(run_cmd)
         };
@@ -953,6 +956,15 @@ impl Configuration {
         Ok(conf)
     }
 
+    fn metrics_config(&self) -> Result<MetricsConfiguration, String> {
+        let conf = MetricsConfiguration {
+            enabled: self.metrics_enabled(),
+            interface: self.metrics_interface(),
+            port: self.args.arg_ports_shift + self.args.arg_metrics_port,
+        };
+        Ok(conf)
+    }
+
     fn snapshot_config(&self) -> Result<SnapshotConfiguration, String> {
         let conf = SnapshotConfiguration {
             no_periodic: self.args.flag_no_periodic_snapshot,
@@ -1048,6 +1060,10 @@ impl Configuration {
         self.interface(&self.args.arg_ws_interface)
     }
 
+    fn metrics_interface(&self) -> String {
+        self.interface(&self.args.arg_metrics_interface)
+    }
+
     fn secretstore_interface(&self) -> String {
         self.interface(&self.args.arg_secretstore_interface)
     }
@@ -1128,6 +1144,10 @@ impl Configuration {
         !self.args.flag_no_ws
     }
 
+    fn metrics_enabled(&self) -> bool {
+        self.args.flag_metrics
+    }
+
     fn secretstore_enabled(&self) -> bool {
         !self.args.flag_no_secretstore && cfg!(feature = "secretstore")
     }
@@ -1531,6 +1551,7 @@ mod tests {
             verifier_settings: Default::default(),
             no_persistent_txqueue: false,
             max_round_blocks_to_import: 12,
+            metrics_conf: MetricsConfiguration::default(),
         };
         expected.secretstore_conf.enabled = cfg!(feature = "secretstore");
         expected.secretstore_conf.http_enabled = cfg!(feature = "secretstore");
diff --git a/parity/informant.rs b/parity/informant.rs
index 791ec981b..9eaf52850 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -146,7 +146,6 @@ impl InformantData for FullNodeInformantData {
         let chain_info = self.client.chain_info();
 
         let mut cache_sizes = CacheSizes::default();
-        cache_sizes.insert("db", client_report.state_db_mem);
         cache_sizes.insert("queue", queue_info.mem_used);
         cache_sizes.insert("chain", blockchain_cache_info.total());
 
@@ -157,8 +156,6 @@ impl InformantData for FullNodeInformantData {
                 let num_peers_range = net.num_peers_range();
                 debug_assert!(num_peers_range.end() >= num_peers_range.start());
 
-                cache_sizes.insert("sync", status.mem_used);
-
                 Some(SyncInfo {
                     last_imported_block_number: status
                         .last_imported_block_number
@@ -247,10 +244,15 @@ impl<T: InformantData> Informant<T> {
 
         let rpc_stats = self.rpc_stats.as_ref();
         let snapshot_sync = sync_info.as_ref().map_or(false, |s| s.snapshot_sync)
-            && self.snapshot.as_ref().map_or(false, |s| match s.status() {
-                RestorationStatus::Ongoing { .. } | RestorationStatus::Initializing { .. } => true,
-                _ => false,
-            });
+            && self
+                .snapshot
+                .as_ref()
+                .map_or(false, |s| match s.restoration_status() {
+                    RestorationStatus::Ongoing { .. } | RestorationStatus::Initializing { .. } => {
+                        true
+                    }
+                    _ => false,
+                });
         if !importing && !snapshot_sync && elapsed < Duration::from_secs(30) {
             return;
         }
@@ -285,8 +287,8 @@ impl<T: InformantData> Informant<T> {
                     ),
                     true => {
                         self.snapshot.as_ref().map_or(String::new(), |s|
-                            match s.status() {
-                                RestorationStatus::Ongoing { state_chunks, block_chunks, state_chunks_done, block_chunks_done } => {
+                            match s.restoration_status() {
+                                RestorationStatus::Ongoing { state_chunks, block_chunks, state_chunks_done, block_chunks_done, .. } => {
                                     format!("Syncing snapshot {}/{}", state_chunks_done + block_chunks_done, state_chunks + block_chunks)
                                 },
                                 RestorationStatus::Initializing { chunks_done } => {
diff --git a/parity/lib.rs b/parity/lib.rs
index 863ba1cab..5fbfe8535 100644
--- a/parity/lib.rs
+++ b/parity/lib.rs
@@ -55,6 +55,7 @@ extern crate ethereum_types;
 extern crate ethkey;
 extern crate ethstore;
 extern crate fetch;
+extern crate hyper;
 extern crate journaldb;
 extern crate keccak_hash as hash;
 extern crate kvdb;
@@ -65,7 +66,9 @@ extern crate parity_path as path;
 extern crate parity_rpc;
 extern crate parity_runtime;
 extern crate parity_version;
+extern crate prometheus;
 extern crate registrar;
+extern crate stats;
 
 #[macro_use]
 extern crate log as rlog;
@@ -96,6 +99,7 @@ mod configuration;
 mod db;
 mod helpers;
 mod informant;
+mod metrics;
 mod modules;
 mod params;
 mod presale;
diff --git a/parity/metrics.rs b/parity/metrics.rs
new file mode 100644
index 000000000..da083bd8d
--- /dev/null
+++ b/parity/metrics.rs
@@ -0,0 +1,108 @@
+use std::{sync::Arc, time::Instant};
+
+use crate::{futures::Future, rpc, rpc_apis};
+
+use parking_lot::Mutex;
+
+use hyper::{service::service_fn_ok, Body, Method, Request, Response, Server, StatusCode};
+
+use stats::{
+    prometheus::{self, Encoder},
+    prometheus_gauge, PrometheusMetrics,
+};
+
+#[derive(Debug, Clone, PartialEq)]
+pub struct MetricsConfiguration {
+    /// Are metrics enabled (default is false)?
+    pub enabled: bool,
+    /// The IP of the network interface used (default is 127.0.0.1).
+    pub interface: String,
+    /// The network port (default is 3000).
+    pub port: u16,
+}
+
+impl Default for MetricsConfiguration {
+    fn default() -> Self {
+        MetricsConfiguration {
+            enabled: false,
+            interface: "127.0.0.1".into(),
+            port: 3000,
+        }
+    }
+}
+
+struct State {
+    rpc_apis: Arc<rpc_apis::FullDependencies>,
+}
+
+fn handle_request(req: Request<Body>, state: Arc<Mutex<State>>) -> Response<Body> {
+    let (parts, _body) = req.into_parts();
+    match (parts.method, parts.uri.path()) {
+        (Method::GET, "/metrics") => {
+            let start = Instant::now();
+
+            let mut reg = prometheus::Registry::new();
+            let state = state.lock();
+            state.rpc_apis.client.prometheus_metrics(&mut reg);
+            state.rpc_apis.sync.prometheus_metrics(&mut reg);
+            let elapsed = start.elapsed();
+            prometheus_gauge(
+                &mut reg,
+                "metrics_time",
+                "Time to perform rpc metrics",
+                elapsed.as_millis() as i64,
+            );
+
+            let mut buffer = vec![];
+            let encoder = prometheus::TextEncoder::new();
+            let metric_families = reg.gather();
+
+            encoder
+                .encode(&metric_families, &mut buffer)
+                .expect("all source of metrics are static; qed");
+            let text = String::from_utf8(buffer).expect("metrics encoding is ASCII; qed");
+
+            Response::new(Body::from(text))
+        }
+        (_, _) => {
+            let mut res = Response::new(Body::from("not found"));
+            *res.status_mut() = StatusCode::NOT_FOUND;
+            res
+        }
+    }
+}
+
+/// Start the prometheus metrics server accessible via GET <host>:<port>/metrics
+pub fn start_prometheus_metrics(
+    conf: &MetricsConfiguration,
+    deps: &rpc::Dependencies<rpc_apis::FullDependencies>,
+) -> Result<(), String> {
+    if !conf.enabled {
+        return Ok(());
+    }
+
+    let addr = format!("{}:{}", conf.interface, conf.port);
+    let addr = addr
+        .parse()
+        .map_err(|err| format!("Failed to parse address '{}': {}", addr, err))?;
+
+    let state = State {
+        rpc_apis: deps.apis.clone(),
+    };
+    let state = Arc::new(Mutex::new(state));
+
+    let server = Server::bind(&addr)
+        .serve(move || {
+            // This is the `Service` that will handle the connection.
+            // `service_fn_ok` is a helper to convert a function that
+            // returns a Response into a `Service`.
+            let state = state.clone();
+            service_fn_ok(move |req: Request<Body>| handle_request(req, state.clone()))
+        })
+        .map_err(|e| eprintln!("server error: {}", e));
+    println!("Listening on http://{}", addr);
+
+    deps.executor.spawn(server);
+
+    Ok(())
+}
diff --git a/parity/run.rs b/parity/run.rs
index 9c263fca7..1e36519ec 100644
--- a/parity/run.rs
+++ b/parity/run.rs
@@ -38,6 +38,7 @@ use helpers::{execute_upgrades, passwords_from_files, to_client_config};
 use informant::{FullNodeInformantData, Informant};
 use journaldb::Algorithm;
 use jsonrpc_core;
+use metrics::{start_prometheus_metrics, MetricsConfiguration};
 use miner::{external::ExternalMiner, work_notify::WorkPoster};
 use modules;
 use node_filter::NodeFilter;
@@ -109,6 +110,7 @@ pub struct RunCmd {
     pub verifier_settings: VerifierSettings,
     pub no_persistent_txqueue: bool,
     pub max_round_blocks_to_import: usize,
+    pub metrics_conf: MetricsConfiguration,
 }
 
 // node info fetcher for the local store.
@@ -496,6 +498,10 @@ pub fn execute(cmd: RunCmd, logger: Arc<RotatingLogger>) -> Result<RunningClient
     let rpc_direct = rpc::setup_apis(rpc_apis::ApiSet::All, &dependencies);
     let ws_server = rpc::new_ws(cmd.ws_conf.clone(), &dependencies)?;
     let ipc_server = rpc::new_ipc(cmd.ipc_conf, &dependencies)?;
+
+    // start the prometheus metrics server
+    start_prometheus_metrics(&cmd.metrics_conf, &dependencies)?;
+
     let http_server = rpc::new_http(
         "HTTP JSON-RPC",
         "jsonrpc",
diff --git a/parity/snapshot.rs b/parity/snapshot.rs
index 13477c343..6c51d06d7 100644
--- a/parity/snapshot.rs
+++ b/parity/snapshot.rs
@@ -96,7 +96,7 @@ fn restore_using<R: SnapshotReader>(
             state_chunks_done,
             block_chunks_done,
             ..
-        } = informant_handle.status()
+        } = informant_handle.restoration_status()
         {
             info!(
                 "Processed {}/{} state chunks and {}/{} block chunks.",
@@ -108,7 +108,7 @@ fn restore_using<R: SnapshotReader>(
 
     info!("Restoring state");
     for &state_hash in &manifest.state_hashes {
-        if snapshot.status() == RestorationStatus::Failed {
+        if snapshot.restoration_status() == RestorationStatus::Failed {
             return Err("Restoration failed".into());
         }
 
@@ -132,7 +132,7 @@ fn restore_using<R: SnapshotReader>(
 
     info!("Restoring blocks");
     for &block_hash in &manifest.block_hashes {
-        if snapshot.status() == RestorationStatus::Failed {
+        if snapshot.restoration_status() == RestorationStatus::Failed {
             return Err("Restoration failed".into());
         }
 
@@ -153,7 +153,7 @@ fn restore_using<R: SnapshotReader>(
         snapshot.feed_block_chunk(block_hash, &chunk);
     }
 
-    match snapshot.status() {
+    match snapshot.restoration_status() {
         RestorationStatus::Ongoing { .. } => {
             Err("Snapshot file is incomplete and missing chunks.".into())
         }
diff --git a/rpc/src/v1/impls/eth.rs b/rpc/src/v1/impls/eth.rs
index 420526f5a..f1c081527 100644
--- a/rpc/src/v1/impls/eth.rs
+++ b/rpc/src/v1/impls/eth.rs
@@ -575,7 +575,7 @@ where
 
         let status = self.sync.status();
         let client = &self.client;
-        let snapshot_status = self.snapshot.status();
+        let snapshot_status = self.snapshot.restoration_status();
 
         let (warping, warp_chunks_amount, warp_chunks_processed) = match snapshot_status {
             RestorationStatus::Ongoing {
@@ -583,6 +583,7 @@ where
                 block_chunks,
                 state_chunks_done,
                 block_chunks_done,
+                ..
             } => (
                 true,
                 Some(block_chunks + state_chunks),
diff --git a/rpc/src/v1/impls/parity.rs b/rpc/src/v1/impls/parity.rs
index 0d8f68cf6..7f93bcd3e 100644
--- a/rpc/src/v1/impls/parity.rs
+++ b/rpc/src/v1/impls/parity.rs
@@ -29,6 +29,7 @@ use ethereum_types::{Address, H160, H256, H512, H64, U256, U64};
 use ethkey::{crypto::ecies, Brain, Generator};
 use ethstore::random_phrase;
 use jsonrpc_core::{futures::future, BoxFuture, Result};
+use stats::PrometheusMetrics;
 use sync::{ManageNetwork, SyncProvider};
 use types::ids::BlockId;
 use version::version_data;
@@ -52,7 +53,10 @@ use v1::{
 use Host;
 
 /// Parity implementation.
-pub struct ParityClient<C, M> {
+pub struct ParityClient<C, M>
+where
+    C: PrometheusMetrics,
+{
     client: Arc<C>,
     miner: Arc<M>,
     sync: Arc<dyn SyncProvider>,
@@ -66,7 +70,7 @@ pub struct ParityClient<C, M> {
 
 impl<C, M> ParityClient<C, M>
 where
-    C: BlockChainClient,
+    C: BlockChainClient + PrometheusMetrics,
 {
     /// Creates new `ParityClient`.
     pub fn new(
@@ -99,6 +103,7 @@ where
     S: StateInfo + 'static,
     C: miner::BlockChainClient
         + BlockChainClient
+        + PrometheusMetrics
         + StateClient<State = S>
         + Call<State = S>
         + 'static,
@@ -458,7 +463,7 @@ where
 
     fn status(&self) -> Result<()> {
         let has_peers = self.settings.is_dev_chain || self.sync.status().num_peers > 0;
-        let is_warping = match self.snapshot.as_ref().map(|s| s.status()) {
+        let is_warping = match self.snapshot.as_ref().map(|s| s.restoration_status()) {
             Some(RestorationStatus::Ongoing { .. }) => true,
             _ => false,
         };
diff --git a/rpc/src/v1/tests/helpers/snapshot_service.rs b/rpc/src/v1/tests/helpers/snapshot_service.rs
index fa5170242..ea6392901 100644
--- a/rpc/src/v1/tests/helpers/snapshot_service.rs
+++ b/rpc/src/v1/tests/helpers/snapshot_service.rs
@@ -14,7 +14,7 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity Ethereum.  If not, see <http://www.gnu.org/licenses/>.
 
-use ethcore::snapshot::{ManifestData, RestorationStatus, SnapshotService};
+use ethcore::snapshot::{CreationStatus, ManifestData, RestorationStatus, SnapshotService};
 
 use bytes::Bytes;
 use ethereum_types::H256;
@@ -53,9 +53,12 @@ impl SnapshotService for TestSnapshotService {
     fn chunk(&self, _hash: H256) -> Option<Bytes> {
         None
     }
-    fn status(&self) -> RestorationStatus {
+    fn restoration_status(&self) -> RestorationStatus {
         self.status.lock().clone()
     }
+    fn creation_status(&self) -> CreationStatus {
+        CreationStatus::Inactive
+    }
     fn begin_restore(&self, _manifest: ManifestData) {}
     fn abort_restore(&self) {}
     fn abort_snapshot(&self) {}
diff --git a/rpc/src/v1/tests/helpers/sync_provider.rs b/rpc/src/v1/tests/helpers/sync_provider.rs
index afdfeec5d..ee70e8797 100644
--- a/rpc/src/v1/tests/helpers/sync_provider.rs
+++ b/rpc/src/v1/tests/helpers/sync_provider.rs
@@ -19,6 +19,7 @@
 use ethereum_types::H256;
 use network::client_version::ClientVersion;
 use parking_lot::RwLock;
+use stats::{prometheus, PrometheusMetrics};
 use std::collections::BTreeMap;
 use sync::{EthProtocolInfo, PeerInfo, SyncProvider, SyncState, SyncStatus, TransactionStats};
 
@@ -51,10 +52,10 @@ impl TestSyncProvider {
                 blocks_received: 0,
                 num_peers: config.num_peers,
                 num_active_peers: 0,
-                mem_used: 0,
                 num_snapshot_chunks: 0,
                 snapshot_chunks_done: 0,
                 last_imported_old_block_number: None,
+                item_sizes: BTreeMap::new(),
             }),
         }
     }
@@ -67,6 +68,10 @@ impl TestSyncProvider {
     }
 }
 
+impl PrometheusMetrics for TestSyncProvider {
+    fn prometheus_metrics(&self, _: &mut prometheus::Registry) {}
+}
+
 impl SyncProvider for TestSyncProvider {
     fn status(&self) -> SyncStatus {
         self.status.read().clone()
diff --git a/rpc/src/v1/tests/mocked/eth.rs b/rpc/src/v1/tests/mocked/eth.rs
index fbaad7027..42ab6c0da 100644
--- a/rpc/src/v1/tests/mocked/eth.rs
+++ b/rpc/src/v1/tests/mocked/eth.rs
@@ -180,6 +180,7 @@ fn rpc_eth_syncing() {
 
     let snap_res = r#"{"jsonrpc":"2.0","result":{"currentBlock":"0x3e8","highestBlock":"0x9c4","startingBlock":"0x0","warpChunksAmount":"0x32","warpChunksProcessed":"0x18"},"id":1}"#;
     tester.snapshot.set_status(RestorationStatus::Ongoing {
+        block_number: 0,
         state_chunks: 40,
         block_chunks: 10,
         state_chunks_done: 18,
diff --git a/scripts/prometheus/config/grafana/dashboards/oe.json b/scripts/prometheus/config/grafana/dashboards/oe.json
new file mode 100644
index 000000000..17beec651
--- /dev/null
+++ b/scripts/prometheus/config/grafana/dashboards/oe.json
@@ -0,0 +1,1576 @@
+{
+    "annotations": {
+      "list": [
+        {
+          "builtIn": 1,
+          "datasource": "-- Grafana --",
+          "enable": true,
+          "hide": true,
+          "iconColor": "rgba(0, 211, 255, 1)",
+          "name": "Annotations & Alerts",
+          "type": "dashboard"
+        }
+      ]
+    },
+    "editable": true,
+    "gnetId": null,
+    "graphTooltip": 0,
+    "id": 3,
+    "links": [],
+    "panels": [
+      {
+        "cacheTimeout": null,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {
+              "align": null
+            },
+            "mappings": [],
+            "thresholds": {
+              "mode": "absolute",
+              "steps": [
+                {
+                  "color": "green",
+                  "value": null
+                },
+                {
+                  "color": "red",
+                  "value": 80
+                }
+              ]
+            }
+          },
+          "overrides": []
+        },
+        "gridPos": {
+          "h": 3,
+          "w": 4,
+          "x": 0,
+          "y": 0
+        },
+        "id": 20,
+        "interval": "",
+        "links": [],
+        "maxDataPoints": 0,
+        "options": {
+          "colorMode": "value",
+          "graphMode": "area",
+          "justifyMode": "auto",
+          "orientation": "auto",
+          "reduceOptions": {
+            "calcs": [
+              "mean"
+            ],
+            "fields": "",
+            "values": false
+          }
+        },
+        "pluginVersion": "7.0.3",
+        "targets": [
+          {
+            "expr": "oe_sync_blocks_highest",
+            "interval": "",
+            "legendFormat": "",
+            "refId": "A"
+          }
+        ],
+        "timeFrom": null,
+        "timeShift": null,
+        "title": "Highest block",
+        "transformations": [
+          {
+            "id": "reduce",
+            "options": {}
+          }
+        ],
+        "type": "stat"
+      },
+      {
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {},
+            "mappings": [],
+            "thresholds": {
+              "mode": "absolute",
+              "steps": [
+                {
+                  "color": "green",
+                  "value": null
+                },
+                {
+                  "color": "red",
+                  "value": 80
+                }
+              ]
+            }
+          },
+          "overrides": []
+        },
+        "gridPos": {
+          "h": 3,
+          "w": 2,
+          "x": 4,
+          "y": 0
+        },
+        "id": 29,
+        "options": {
+          "colorMode": "value",
+          "graphMode": "area",
+          "justifyMode": "auto",
+          "orientation": "auto",
+          "reduceOptions": {
+            "calcs": [
+              "mean"
+            ],
+            "fields": "",
+            "values": false
+          }
+        },
+        "pluginVersion": "7.0.3",
+        "targets": [
+          {
+            "expr": "oe_prunning_earliest_state",
+            "interval": "",
+            "legendFormat": "",
+            "refId": "A"
+          }
+        ],
+        "timeFrom": null,
+        "timeShift": null,
+        "title": "Earliest non pruned state",
+        "transformations": [
+          {
+            "id": "reduce",
+            "options": {}
+          }
+        ],
+        "type": "stat"
+      },
+      {
+        "cacheTimeout": null,
+        "colorBackground": false,
+        "colorValue": false,
+        "colors": [
+          "#299c46",
+          "rgba(237, 129, 40, 0.89)",
+          "#d44a3a"
+        ],
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "format": "none",
+        "gauge": {
+          "maxValue": 100,
+          "minValue": 0,
+          "show": false,
+          "thresholdLabels": false,
+          "thresholdMarkers": true
+        },
+        "gridPos": {
+          "h": 2,
+          "w": 3,
+          "x": 6,
+          "y": 0
+        },
+        "id": 24,
+        "interval": null,
+        "links": [],
+        "mappingType": 1,
+        "mappingTypes": [
+          {
+            "name": "value to text",
+            "value": 1
+          },
+          {
+            "name": "range to text",
+            "value": 2
+          }
+        ],
+        "maxDataPoints": 100,
+        "nullPointMode": "connected",
+        "nullText": null,
+        "postfix": "",
+        "postfixFontSize": "50%",
+        "prefix": "",
+        "prefixFontSize": "50%",
+        "rangeMaps": [
+          {
+            "from": "null",
+            "text": "N/A",
+            "to": "null"
+          }
+        ],
+        "sparkline": {
+          "fillColor": "rgba(31, 118, 189, 0.18)",
+          "full": false,
+          "lineColor": "rgb(31, 120, 193)",
+          "show": false,
+          "ymax": null,
+          "ymin": null
+        },
+        "tableColumn": "oe_sync_status{instance=\"localhost:8545\", job=\"openethereum\"}",
+        "targets": [
+          {
+            "expr": "oe_sync_status",
+            "refId": "A"
+          }
+        ],
+        "thresholds": "",
+        "timeFrom": null,
+        "timeShift": null,
+        "title": "Sync status",
+        "type": "singlestat",
+        "valueFontSize": "80%",
+        "valueMaps": [
+          {
+            "op": "=",
+            "text": "WaitingPeers",
+            "value": "0"
+          },
+          {
+            "op": "=",
+            "text": "Waiting",
+            "value": "6"
+          },
+          {
+            "op": "=",
+            "text": "SnapshotManifest",
+            "value": "1"
+          },
+          {
+            "op": "=",
+            "text": "SnapshotData",
+            "value": "2"
+          },
+          {
+            "op": "=",
+            "text": "SnapshotWaiting",
+            "value": "3"
+          },
+          {
+            "op": "=",
+            "text": "Blocks",
+            "value": "4"
+          },
+          {
+            "op": "=",
+            "text": "Idle",
+            "value": "5"
+          },
+          {
+            "op": "=",
+            "text": "NewBlocks",
+            "value": "7"
+          }
+        ],
+        "valueName": "current"
+      },
+      {
+        "aliasColors": {},
+        "bars": true,
+        "cacheTimeout": null,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 3,
+          "w": 3,
+          "x": 9,
+          "y": 0
+        },
+        "hiddenSeries": false,
+        "id": 28,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": false,
+        "linewidth": 1,
+        "links": [],
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_metrics_time",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "RPC Metrics Reponse time",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "ms",
+            "label": null,
+            "logBase": 1,
+            "max": "1000",
+            "min": "0",
+            "show": false
+          },
+          {
+            "decimals": null,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": false
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 4,
+          "x": 12,
+          "y": 0
+        },
+        "hiddenSeries": false,
+        "id": 8,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "rate(oe_import_blocks[1m])",
+            "interval": "",
+            "legendFormat": "",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Block/s",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 4,
+          "x": 16,
+          "y": 0
+        },
+        "hiddenSeries": false,
+        "id": 6,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "rate(oe_import_gas[1m])/1000000",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "MGas/s",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 4,
+          "x": 20,
+          "y": 0
+        },
+        "hiddenSeries": false,
+        "id": 10,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "rate(oe_import_txs[1m])",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Tx/s",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 5,
+          "w": 12,
+          "x": 0,
+          "y": 3
+        },
+        "hiddenSeries": false,
+        "id": 16,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pluginVersion": "6.5.2",
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_net_peers",
+            "refId": "A"
+          },
+          {
+            "expr": "oe_net_active_peers",
+            "refId": "B"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Peers",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 6,
+          "x": 12,
+          "y": 4
+        },
+        "hiddenSeries": false,
+        "id": 12,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "rate(oe_io_bytes_read[1m])",
+            "interval": "",
+            "legendFormat": "",
+            "refId": "A"
+          },
+          {
+            "expr": "rate(oe_io_bytes_written[1m])",
+            "interval": "",
+            "legendFormat": "",
+            "refId": "B"
+          },
+          {
+            "expr": "rate(oe_io_cache_read_bytes[1m])/60",
+            "refId": "C"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "DB IO",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "decimals": null,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 6,
+          "x": 18,
+          "y": 4
+        },
+        "hiddenSeries": false,
+        "id": 14,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": true,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_queue_size_unverified",
+            "refId": "A"
+          },
+          {
+            "expr": "oe_queue_size_verified",
+            "refId": "B"
+          },
+          {
+            "expr": "oe_queue_size_verifying",
+            "refId": "C"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Queue",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": "",
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": "",
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 3,
+          "x": 0,
+          "y": 8
+        },
+        "hiddenSeries": false,
+        "id": 4,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [
+          {}
+        ],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_snapshot_download_chunks - oe_snapshot_download_chunks_done",
+            "legendFormat": "Pending blocks",
+            "refId": "A"
+          },
+          {
+            "expr": "rate(oe_snapshot_download_chunks_done[5m])*3600",
+            "legendFormat": "Rate per hour",
+            "refId": "B"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Pending Snapshot download",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 3,
+          "x": 3,
+          "y": 8
+        },
+        "hiddenSeries": false,
+        "id": 27,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_snapshot_restore_block",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Snapshot restore",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 3,
+          "x": 6,
+          "y": 8
+        },
+        "hiddenSeries": false,
+        "id": 31,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_chain_block - oe_chain_warpsync_gap_last",
+            "interval": "",
+            "legendFormat": "",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Snapshot GAP",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 3,
+          "x": 9,
+          "y": 8
+        },
+        "hiddenSeries": false,
+        "id": 26,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": false,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_snapshot_create_block",
+            "refId": "A"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Snapshot create",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "decimals": 0,
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "cacheTimeout": null,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 6,
+          "x": 12,
+          "y": 8
+        },
+        "hiddenSeries": false,
+        "id": 22,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "links": [],
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": true,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_blockchaincache_block_details",
+            "refId": "A"
+          },
+          {
+            "expr": "oe_blockchaincache_block_recipts",
+            "refId": "B"
+          },
+          {
+            "expr": "oe_blockchaincache_blocks",
+            "refId": "C"
+          },
+          {
+            "expr": "oe_blockchaincache_txaddrs",
+            "refId": "D"
+          },
+          {
+            "expr": "",
+            "refId": "E"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Blockchain cache",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "decimals": 0,
+            "format": "decbytes",
+            "label": "",
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          },
+          {
+            "decimals": 0,
+            "format": "bytes",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": "0",
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      },
+      {
+        "aliasColors": {},
+        "bars": false,
+        "dashLength": 10,
+        "dashes": false,
+        "datasource": null,
+        "fieldConfig": {
+          "defaults": {
+            "custom": {}
+          },
+          "overrides": []
+        },
+        "fill": 1,
+        "fillGradient": 0,
+        "gridPos": {
+          "h": 4,
+          "w": 6,
+          "x": 18,
+          "y": 8
+        },
+        "hiddenSeries": false,
+        "id": 2,
+        "legend": {
+          "avg": false,
+          "current": false,
+          "max": false,
+          "min": false,
+          "show": false,
+          "total": false,
+          "values": false
+        },
+        "lines": true,
+        "linewidth": 1,
+        "nullPointMode": "null",
+        "options": {
+          "dataLinks": []
+        },
+        "percentage": false,
+        "pointradius": 2,
+        "points": false,
+        "renderer": "flot",
+        "seriesOverrides": [],
+        "spaceLength": 10,
+        "stack": true,
+        "steppedLine": false,
+        "targets": [
+          {
+            "expr": "oe_queue_mem_used",
+            "refId": "A"
+          },
+          {
+            "expr": "oe_sync_mem_used",
+            "refId": "B"
+          },
+          {
+            "expr": "oe_statedb_mem_used",
+            "refId": "C"
+          }
+        ],
+        "thresholds": [],
+        "timeFrom": null,
+        "timeRegions": [],
+        "timeShift": null,
+        "title": "Memory",
+        "tooltip": {
+          "shared": true,
+          "sort": 0,
+          "value_type": "individual"
+        },
+        "type": "graph",
+        "xaxis": {
+          "buckets": null,
+          "mode": "time",
+          "name": null,
+          "show": false,
+          "values": []
+        },
+        "yaxes": [
+          {
+            "format": "bytes",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          },
+          {
+            "format": "short",
+            "label": null,
+            "logBase": 1,
+            "max": null,
+            "min": null,
+            "show": true
+          }
+        ],
+        "yaxis": {
+          "align": false,
+          "alignLevel": null
+        }
+      }
+    ],
+    "refresh": false,
+    "schemaVersion": 25,
+    "style": "dark",
+    "tags": [],
+    "templating": {
+      "list": []
+    },
+    "time": {
+      "from": "2020-06-10T16:05:07.848Z",
+      "to": "2020-06-10T16:08:24.212Z"
+    },
+    "timepicker": {
+      "refresh_intervals": [
+        "10s",
+        "30s",
+        "1m",
+        "5m",
+        "15m",
+        "30m",
+        "1h",
+        "2h",
+        "1d"
+      ]
+    },
+    "timezone": "",
+    "title": "OpenEthereum",
+    "uid": "fH2SyJiMz",
+    "version": 2
+  }
\ No newline at end of file
diff --git a/scripts/prometheus/config/grafana/grafana.ini b/scripts/prometheus/config/grafana/grafana.ini
new file mode 100644
index 000000000..dba20ae99
--- /dev/null
+++ b/scripts/prometheus/config/grafana/grafana.ini
@@ -0,0 +1,705 @@
+##################### Grafana Configuration Defaults #####################
+#
+# Do not modify this file in grafana installs
+#
+
+# possible values : production, development
+app_mode = production
+
+# instance name, defaults to HOSTNAME environment variable value or hostname if HOSTNAME var is empty
+instance_name = ${HOSTNAME}
+
+#################################### Paths ###############################
+[paths]
+# Path to where grafana can store temp files, sessions, and the sqlite3 db (if that is used)
+data = data
+
+# Temporary files in `data` directory older than given duration will be removed
+temp_data_lifetime = 24h
+
+# Directory where grafana can store logs
+logs = data/log
+
+# Directory where grafana will automatically scan and look for plugins
+plugins = data/plugins
+
+# folder that contains provisioning config files that grafana will apply on startup and while running.
+provisioning = conf/provisioning
+
+#################################### Server ##############################
+[server]
+# Protocol (http, https, h2, socket)
+protocol = http
+
+# The ip address to bind to, empty will bind to all interfaces
+http_addr =
+
+# The http port to use
+http_port = 3000
+
+# The public facing domain name used to access grafana from a browser
+domain = localhost
+
+# Redirect to correct domain if host header does not match domain
+# Prevents DNS rebinding attacks
+enforce_domain = false
+
+# The full public facing url
+root_url = %(protocol)s://%(domain)s:%(http_port)s/
+
+# Serve Grafana from subpath specified in `root_url` setting. By default it is set to `false` for compatibility reasons.
+serve_from_sub_path = false
+
+# Log web requests
+router_logging = false
+
+# the path relative working path
+static_root_path = public
+
+# enable gzip
+enable_gzip = false
+
+# https certs & key file
+cert_file =
+cert_key =
+
+# Unix socket path
+socket = /tmp/grafana.sock
+
+#################################### Database ############################
+[database]
+# You can configure the database connection by specifying type, host, name, user and password
+# as separate properties or as on string using the url property.
+
+# Either "mysql", "postgres" or "sqlite3", it's your choice
+type = sqlite3
+host = 127.0.0.1:3306
+name = grafana
+user = root
+# If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
+password =
+# Use either URL or the previous fields to configure the database
+# Example: mysql://user:secret@host:port/database
+url =
+
+# Max idle conn setting default is 2
+max_idle_conn = 2
+
+# Max conn setting default is 0 (mean not set)
+max_open_conn =
+
+# Connection Max Lifetime default is 14400 (means 14400 seconds or 4 hours)
+conn_max_lifetime = 14400
+
+# Set to true to log the sql calls and execution times.
+log_queries =
+
+# For "postgres", use either "disable", "require" or "verify-full"
+# For "mysql", use either "true", "false", or "skip-verify".
+ssl_mode = disable
+
+ca_cert_path =
+client_key_path =
+client_cert_path =
+server_cert_name =
+
+# For "sqlite3" only, path relative to data_path setting
+path = grafana.db
+
+# For "sqlite3" only. cache mode setting used for connecting to the database
+cache_mode = private
+
+#################################### Cache server #############################
+[remote_cache]
+# Either "redis", "memcached" or "database" default is "database"
+type = database
+
+# cache connectionstring options
+# database: will use Grafana primary database.
+# redis: config like redis server e.g. `addr=127.0.0.1:6379,pool_size=100,db=0,ssl=false`. Only addr is required. ssl may be 'true', 'false', or 'insecure'.
+# memcache: 127.0.0.1:11211
+connstr =
+
+#################################### Data proxy ###########################
+[dataproxy]
+
+# This enables data proxy logging, default is false
+logging = false
+
+# How long the data proxy should wait before timing out default is 30 (seconds)
+timeout = 30
+
+# If enabled and user is not anonymous, data proxy will add X-Grafana-User header with username into the request, default is false.
+send_user_header = false
+
+#################################### Analytics ###########################
+[analytics]
+# Server reporting, sends usage counters to stats.grafana.org every 24 hours.
+# No ip addresses are being tracked, only simple counters to track
+# running instances, dashboard and error counts. It is very helpful to us.
+# Change this option to false to disable reporting.
+reporting_enabled = true
+
+# Set to false to disable all checks to https://grafana.com
+# for new versions (grafana itself and plugins), check is used
+# in some UI views to notify that grafana or plugin update exists
+# This option does not cause any auto updates, nor send any information
+# only a GET request to https://grafana.com to get latest versions
+check_for_updates = true
+
+# Google Analytics universal tracking code, only enabled if you specify an id here
+google_analytics_ua_id =
+
+# Google Tag Manager ID, only enabled if you specify an id here
+google_tag_manager_id =
+
+#################################### Security ############################
+[security]
+# disable creation of admin user on first start of grafana
+disable_initial_admin_creation = false
+
+# default admin user, created on startup
+admin_user = admin
+
+# default admin password, can be changed before first start of grafana, or in profile settings
+admin_password = admin
+
+# used for signing
+secret_key = SW2YcwTIb9zpOOhoPsMm
+
+# disable gravatar profile images
+disable_gravatar = false
+
+# data source proxy whitelist (ip_or_domain:port separated by spaces)
+data_source_proxy_whitelist =
+
+# disable protection against brute force login attempts
+disable_brute_force_login_protection = false
+
+# set to true if you host Grafana behind HTTPS. default is false.
+cookie_secure = false
+
+# set cookie SameSite attribute. defaults to `lax`. can be set to "lax", "strict" and "none"
+cookie_samesite = lax
+
+# set to true if you want to allow browsers to render Grafana in a <frame>, <iframe>, <embed> or <object>. default is false.
+allow_embedding = false
+
+# Set to true if you want to enable http strict transport security (HSTS) response header.
+# This is only sent when HTTPS is enabled in this configuration.
+# HSTS tells browsers that the site should only be accessed using HTTPS.
+# The default will change to true in the next minor release, 6.3.
+strict_transport_security = false
+
+# Sets how long a browser should cache HSTS. Only applied if strict_transport_security is enabled.
+strict_transport_security_max_age_seconds = 86400
+
+# Set to true if to enable HSTS preloading option. Only applied if strict_transport_security is enabled.
+strict_transport_security_preload = false
+
+# Set to true if to enable the HSTS includeSubDomains option. Only applied if strict_transport_security is enabled.
+strict_transport_security_subdomains = false
+
+# Set to true to enable the X-Content-Type-Options response header.
+# The X-Content-Type-Options response HTTP header is a marker used by the server to indicate that the MIME types advertised
+# in the Content-Type headers should not be changed and be followed. The default will change to true in the next minor release, 6.3.
+x_content_type_options = false
+
+# Set to true to enable the X-XSS-Protection header, which tells browsers to stop pages from loading
+# when they detect reflected cross-site scripting (XSS) attacks. The default will change to true in the next minor release, 6.3.
+x_xss_protection = false
+
+
+#################################### Snapshots ###########################
+[snapshots]
+# snapshot sharing options
+external_enabled = true
+external_snapshot_url = https://snapshots-origin.raintank.io
+external_snapshot_name = Publish to snapshot.raintank.io
+
+# Set to true to enable this Grafana instance act as an external snapshot server and allow unauthenticated requests for
+# creating and deleting snapshots.
+public_mode = false
+
+# remove expired snapshot
+snapshot_remove_expired = true
+
+#################################### Dashboards ##################
+
+[dashboards]
+# Number dashboard versions to keep (per dashboard). Default: 20, Minimum: 1
+versions_to_keep = 20
+
+#################################### Users ###############################
+[users]
+# disable user signup / registration
+allow_sign_up = false
+
+# Allow non admin users to create organizations
+allow_org_create = false
+
+# Set to true to automatically assign new users to the default organization (id 1)
+auto_assign_org = true
+
+# Set this value to automatically add new users to the provided organization (if auto_assign_org above is set to true)
+auto_assign_org_id = 1
+
+# Default role new users will be automatically assigned (if auto_assign_org above is set to true)
+auto_assign_org_role = Viewer
+
+# Require email validation before sign up completes
+verify_email_enabled = false
+
+# Background text for the user field on the login page
+login_hint = email or username
+password_hint = password
+
+# Default UI theme ("dark" or "light")
+default_theme = dark
+
+# External user management
+external_manage_link_url =
+external_manage_link_name =
+external_manage_info =
+
+# Viewers can edit/inspect dashboard settings in the browser. But not save the dashboard.
+viewers_can_edit = false
+
+# Editors can administrate dashboard, folders and teams they create
+editors_can_admin = false
+
+[auth]
+# Login cookie name
+login_cookie_name = grafana_session
+
+# The lifetime (days) an authenticated user can be inactive before being required to login at next visit. Default is 7 days.
+login_maximum_inactive_lifetime_days = 7
+
+# The maximum lifetime (days) an authenticated user can be logged in since login time before being required to login. Default is 30 days.
+login_maximum_lifetime_days = 30
+
+# How often should auth tokens be rotated for authenticated users when being active. The default is each 10 minutes.
+token_rotation_interval_minutes = 10
+
+# Set to true to disable (hide) the login form, useful if you use OAuth
+disable_login_form = false
+
+# Set to true to disable the signout link in the side menu. useful if you use auth.proxy
+disable_signout_menu = false
+
+# URL to redirect the user to after sign out
+signout_redirect_url =
+
+# Set to true to attempt login with OAuth automatically, skipping the login screen.
+# This setting is ignored if multiple OAuth providers are configured.
+oauth_auto_login = false
+
+# limit of api_key seconds to live before expiration
+api_key_max_seconds_to_live = -1
+
+#################################### Anonymous Auth ######################
+[auth.anonymous]
+# enable anonymous access
+enabled = true
+
+# specify organization name that should be used for unauthenticated users
+org_name = Main Org.
+
+# specify role for unauthenticated users
+org_role = Viewer
+
+#################################### Github Auth #########################
+[auth.github]
+enabled = false
+allow_sign_up = true
+client_id = some_id
+client_secret = some_secret
+scopes = user:email,read:org
+auth_url = https://github.com/login/oauth/authorize
+token_url = https://github.com/login/oauth/access_token
+api_url = https://api.github.com/user
+allowed_domains =
+team_ids =
+allowed_organizations =
+
+#################################### GitLab Auth #########################
+[auth.gitlab]
+enabled = false
+allow_sign_up = true
+client_id = some_id
+client_secret = some_secret
+scopes = api
+auth_url = https://gitlab.com/oauth/authorize
+token_url = https://gitlab.com/oauth/token
+api_url = https://gitlab.com/api/v4
+allowed_domains =
+allowed_groups =
+
+#################################### Google Auth #########################
+[auth.google]
+enabled = false
+allow_sign_up = true
+client_id = some_client_id
+client_secret = some_client_secret
+scopes = https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email
+auth_url = https://accounts.google.com/o/oauth2/auth
+token_url = https://accounts.google.com/o/oauth2/token
+api_url = https://www.googleapis.com/oauth2/v1/userinfo
+allowed_domains =
+hosted_domain =
+
+#################################### Grafana.com Auth ####################
+# legacy key names (so they work in env variables)
+[auth.grafananet]
+enabled = false
+allow_sign_up = true
+client_id = some_id
+client_secret = some_secret
+scopes = user:email
+allowed_organizations =
+
+[auth.grafana_com]
+enabled = false
+allow_sign_up = true
+client_id = some_id
+client_secret = some_secret
+scopes = user:email
+allowed_organizations =
+
+#################################### Generic OAuth #######################
+[auth.generic_oauth]
+name = OAuth
+enabled = false
+allow_sign_up = true
+client_id = some_id
+client_secret = some_secret
+scopes = user:email
+email_attribute_name = email:primary
+email_attribute_path =
+role_attribute_path =
+auth_url =
+token_url =
+api_url =
+allowed_domains =
+team_ids =
+allowed_organizations =
+tls_skip_verify_insecure = false
+tls_client_cert =
+tls_client_key =
+tls_client_ca =
+
+#################################### SAML Auth ###########################
+[auth.saml] # Enterprise only
+# Defaults to false. If true, the feature is enabled
+enabled = false
+
+# Base64-encoded public X.509 certificate. Used to sign requests to the IdP
+certificate =
+
+# Path to the public X.509 certificate. Used to sign requests to the IdP
+certificate_path =
+
+# Base64-encoded private key. Used to decrypt assertions from the IdP
+private_key =
+
+# Path to the private key. Used to decrypt assertions from the IdP
+private_key_path =
+
+# Base64-encoded IdP SAML metadata XML. Used to verify and obtain binding locations from the IdP
+idp_metadata =
+
+# Path to the SAML metadata XML. Used to verify and obtain binding locations from the IdP
+idp_metadata_path =
+
+# URL to fetch SAML IdP metadata. Used to verify and obtain binding locations from the IdP
+idp_metadata_url =
+
+# Duration, since the IdP issued a response and the SP is allowed to process it. Defaults to 90 seconds
+max_issue_delay = 90s
+
+# Duration, for how long the SP's metadata should be valid. Defaults to 48 hours
+metadata_valid_duration = 48h
+
+# Friendly name or name of the attribute within the SAML assertion to use as the user's name
+assertion_attribute_name = displayName
+
+# Friendly name or name of the attribute within the SAML assertion to use as the user's login handle
+assertion_attribute_login = mail
+
+# Friendly name or name of the attribute within the SAML assertion to use as the user's email
+assertion_attribute_email = mail
+
+#################################### Basic Auth ##########################
+[auth.basic]
+enabled = true
+
+#################################### Auth Proxy ##########################
+[auth.proxy]
+enabled = false
+header_name = X-WEBAUTH-USER
+header_property = username
+auto_sign_up = true
+# Deprecated, use sync_ttl instead
+ldap_sync_ttl = 60
+sync_ttl = 60
+whitelist =
+headers =
+enable_login_token = false
+
+#################################### Auth LDAP ###########################
+[auth.ldap]
+enabled = false
+config_file = /etc/grafana/ldap.toml
+allow_sign_up = true
+
+# LDAP backround sync (Enterprise only)
+# At 1 am every day
+sync_cron = "0 0 1 * * *"
+active_sync_enabled = true
+
+#################################### SMTP / Emailing #####################
+[smtp]
+enabled = false
+host = localhost:25
+user =
+# If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
+password =
+cert_file =
+key_file =
+skip_verify = false
+from_address = admin@grafana.localhost
+from_name = Grafana
+ehlo_identity =
+
+[emails]
+welcome_email_on_sign_up = false
+templates_pattern = emails/*.html
+
+#################################### Logging ##########################
+[log]
+# Either "console", "file", "syslog". Default is console and file
+# Use space to separate multiple modes, e.g. "console file"
+mode = console file
+
+# Either "debug", "info", "warn", "error", "critical", default is "info"
+level = info
+
+# optional settings to set different levels for specific loggers. Ex filters = sqlstore:debug
+filters =
+
+# For "console" mode only
+[log.console]
+level =
+
+# log line format, valid options are text, console and json
+format = console
+
+# For "file" mode only
+[log.file]
+level =
+
+# log line format, valid options are text, console and json
+format = text
+
+# This enables automated log rotate(switch of following options), default is true
+log_rotate = true
+
+# Max line number of single file, default is 1000000
+max_lines = 1000000
+
+# Max size shift of single file, default is 28 means 1 << 28, 256MB
+max_size_shift = 28
+
+# Segment log daily, default is true
+daily_rotate = true
+
+# Expired days of log file(delete after max days), default is 7
+max_days = 7
+
+[log.syslog]
+level =
+
+# log line format, valid options are text, console and json
+format = text
+
+# Syslog network type and address. This can be udp, tcp, or unix. If left blank, the default unix endpoints will be used.
+network =
+address =
+
+# Syslog facility. user, daemon and local0 through local7 are valid.
+facility =
+
+# Syslog tag. By default, the process' argv[0] is used.
+tag =
+
+#################################### Usage Quotas ########################
+[quota]
+enabled = false
+
+#### set quotas to -1 to make unlimited. ####
+# limit number of users per Org.
+org_user = 10
+
+# limit number of dashboards per Org.
+org_dashboard = 100
+
+# limit number of data_sources per Org.
+org_data_source = 10
+
+# limit number of api_keys per Org.
+org_api_key = 10
+
+# limit number of orgs a user can create.
+user_org = 10
+
+# Global limit of users.
+global_user = -1
+
+# global limit of orgs.
+global_org = -1
+
+# global limit of dashboards
+global_dashboard = -1
+
+# global limit of api_keys
+global_api_key = -1
+
+# global limit on number of logged in users.
+global_session = -1
+
+#################################### Alerting ############################
+[alerting]
+# Disable alerting engine & UI features
+enabled = true
+# Makes it possible to turn off alert rule execution but alerting UI is visible
+execute_alerts = true
+
+# Default setting for new alert rules. Defaults to categorize error and timeouts as alerting. (alerting, keep_state)
+error_or_timeout = alerting
+
+# Default setting for how Grafana handles nodata or null values in alerting. (alerting, no_data, keep_state, ok)
+nodata_or_nullvalues = no_data
+
+# Alert notifications can include images, but rendering many images at the same time can overload the server
+# This limit will protect the server from render overloading and make sure notifications are sent out quickly
+concurrent_render_limit = 5
+
+# Default setting for alert calculation timeout. Default value is 30
+evaluation_timeout_seconds = 30
+
+# Default setting for alert notification timeout. Default value is 30
+notification_timeout_seconds = 30
+
+# Default setting for max attempts to sending alert notifications. Default value is 3
+max_attempts = 3
+
+
+#################################### Explore #############################
+[explore]
+# Enable the Explore section
+enabled = true
+
+#################################### Internal Grafana Metrics ############
+# Metrics available at HTTP API Url /metrics
+[metrics]
+enabled              = true
+interval_seconds     = 10
+# Disable total stats (stat_totals_*) metrics to be generated
+disable_total_stats = false
+
+#If both are set, basic auth will be required for the metrics endpoint.
+basic_auth_username =
+basic_auth_password =
+
+# Send internal Grafana metrics to graphite
+[metrics.graphite]
+# Enable by setting the address setting (ex localhost:2003)
+address =
+prefix = prod.grafana.%(instance_name)s.
+
+#################################### Grafana.com integration  ##########################
+[grafana_net]
+url = https://grafana.com
+
+[grafana_com]
+url = https://grafana.com
+
+#################################### Distributed tracing ############
+[tracing.jaeger]
+# jaeger destination (ex localhost:6831)
+address =
+# tag that will always be included in when creating new spans. ex (tag1:value1,tag2:value2)
+always_included_tag =
+# Type specifies the type of the sampler: const, probabilistic, rateLimiting, or remote
+sampler_type = const
+# jaeger samplerconfig param
+# for "const" sampler, 0 or 1 for always false/true respectively
+# for "probabilistic" sampler, a probability between 0 and 1
+# for "rateLimiting" sampler, the number of spans per second
+# for "remote" sampler, param is the same as for "probabilistic"
+# and indicates the initial sampling rate before the actual one
+# is received from the mothership
+sampler_param = 1
+# Whether or not to use Zipkin span propagation (x-b3- HTTP headers).
+zipkin_propagation = false
+# Setting this to true disables shared RPC spans.
+# Not disabling is the most common setting when using Zipkin elsewhere in your infrastructure.
+disable_shared_zipkin_spans = false
+
+#################################### External Image Storage ##############
+[external_image_storage]
+# Used for uploading images to public servers so they can be included in slack/email messages.
+# You can choose between (s3, webdav, gcs, azure_blob, local)
+provider =
+
+[external_image_storage.s3]
+endpoint =
+path_style_access =
+bucket_url =
+bucket =
+region =
+path =
+access_key =
+secret_key =
+
+[external_image_storage.webdav]
+url =
+username =
+password =
+public_url =
+
+[external_image_storage.gcs]
+key_file =
+bucket =
+path =
+
+[external_image_storage.azure_blob]
+account_name =
+account_key =
+container_name =
+
+[external_image_storage.local]
+# does not require any configuration
+
+[rendering]
+# Options to configure a remote HTTP image rendering service, e.g. using https://github.com/grafana/grafana-image-renderer.
+# URL to a remote HTTP image renderer service, e.g. http://localhost:8081/render, will enable Grafana to render panels and dashboards to PNG-images using HTTP requests to an external service.
+server_url =
+# If the remote HTTP image renderer service runs on a different server than the Grafana server you may have to configure this to a URL where Grafana is reachable, e.g. http://grafana.domain/.
+callback_url =
+
+[panels]
+# here for to support old env variables, can remove after a few months
+enable_alpha = false
+disable_sanitize_html = false
+
+[plugins]
+enable_alpha = false
+app_tls_skip_verify_insecure = false
+
+[enterprise]
+license_path =
+
+[feature_toggles]
+# enable features, separated by spaces
+enable =
diff --git a/scripts/prometheus/config/grafana/provisioning/dashboards/provider.yaml b/scripts/prometheus/config/grafana/provisioning/dashboards/provider.yaml
new file mode 100644
index 000000000..c7ab0aaf0
--- /dev/null
+++ b/scripts/prometheus/config/grafana/provisioning/dashboards/provider.yaml
@@ -0,0 +1,24 @@
+apiVersion: 1
+
+providers:
+  # <string> an unique provider name. Required
+  - name: 'dashboardprovider'
+    # <int> Org id. Default to 1
+    orgId: 1
+    # <string> name of the dashboard folder.
+    folder: 'dashboards'
+    # <string> folder UID. will be automatically generated if not specified
+    folderUid: ''
+    # <string> provider type. Default to 'file'
+    type: file
+    # <bool> disable dashboard deletion
+    disableDeletion: false
+    # <bool> enable dashboard editing
+    editable: true
+    # <int> how often Grafana will scan for changed dashboards
+    updateIntervalSeconds: 10
+    # <bool> allow updating provisioned dashboards from the UI
+    allowUiUpdates: false
+    options:
+      # <string, required> path to dashboard files on disk. Required when using the 'file' type
+      path: /etc/grafana/dashboards
\ No newline at end of file
diff --git a/scripts/prometheus/config/grafana/provisioning/datasources/prometheus.yaml b/scripts/prometheus/config/grafana/provisioning/datasources/prometheus.yaml
new file mode 100644
index 000000000..c02bb38b3
--- /dev/null
+++ b/scripts/prometheus/config/grafana/provisioning/datasources/prometheus.yaml
@@ -0,0 +1,50 @@
+# config file version
+apiVersion: 1
+
+# list of datasources that should be deleted from the database
+deleteDatasources:
+  - name: Prometheus
+    orgId: 1
+
+# list of datasources to insert/update depending
+# whats available in the database
+datasources:
+  # <string, required> name of the datasource. Required
+- name: Prometheus
+  # <string, required> datasource type. Required
+  type: prometheus
+  # <string, required> access mode. direct or proxy. Required
+  access: proxy
+  # <int> org id. will default to orgId 1 if not specified
+  orgId: 1
+  # <string> url
+  url: http://prometheus:9090
+  # <string> database password, if used
+  password:
+  # <string> database user, if used
+  user:
+  # <string> database name, if used
+  database:
+  # <bool> enable/disable basic auth
+  basicAuth: false
+  # <string> basic auth username, if used
+  basicAuthUser:
+  # <string> basic auth password, if used
+  basicAuthPassword:
+  # <bool> enable/disable with credentials headers
+  withCredentials:
+  # <bool> mark as default datasource. Max one per org
+  isDefault: true
+  # <map> fields that will be converted to json and stored in json_data
+  jsonData:
+     graphiteVersion: "1.1"
+     tlsAuth: false
+     tlsAuthWithCACert: false
+  # <string> json object of data that will be encrypted.
+  secureJsonData:
+    tlsCACert: "..."
+    tlsClientCert: "..."
+    tlsClientKey: "..."
+  version: 1
+  # <bool> allow users to edit datasources from the UI.
+  editable: true
diff --git a/scripts/prometheus/config/prometheus/prometheus.yml b/scripts/prometheus/config/prometheus/prometheus.yml
new file mode 100644
index 000000000..79d098b95
--- /dev/null
+++ b/scripts/prometheus/config/prometheus/prometheus.yml
@@ -0,0 +1,37 @@
+# my global config
+global:
+  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
+  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
+  # scrape_timeout is set to the global default (10s).
+
+# Alertmanager configuration
+alerting:
+  alertmanagers:
+  - static_configs:
+    - targets:
+      # - alertmanager:9093
+
+# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
+rule_files:
+  # - "first_rules.yml"
+  # - "second_rules.yml"
+
+# A scrape configuration containing exactly one endpoint to scrape:
+# Here it's Prometheus itself.
+scrape_configs:
+  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
+  - job_name: 'prometheus'
+    # metrics_path defaults to '/metrics'
+    # scheme defaults to 'http'.
+    static_configs:
+    - targets: ['localhost:9090']
+
+  - job_name: openethereum
+    scrape_interval: 15s
+    metric_relabel_configs:
+      - source_labels: [__name__]
+        target_label: __name__
+        replacement: "oe_${1}"
+    static_configs:
+    - targets:
+      - openethereum:3000
diff --git a/scripts/prometheus/docker-compose.yaml b/scripts/prometheus/docker-compose.yaml
new file mode 100644
index 000000000..97567930e
--- /dev/null
+++ b/scripts/prometheus/docker-compose.yaml
@@ -0,0 +1,37 @@
+version: '3.5'
+services:
+
+  openethereum:
+    build:
+      dockerfile: scripts/docker/alpine/Dockerfile
+      context: ../..
+    ports:
+      - '30303:30303'
+      - '30303:30303/udp'
+      - '8545:8545'
+    links:
+      - prometheus
+
+    entrypoint: ["/home/openethereum/openethereum","--metrics","--metrics-interface=all"]
+
+  prometheus:
+    image: prom/prometheus
+    container_name: prometheus
+    restart: always
+    volumes:
+      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml 
+    ports:
+      - '9090:9090'
+
+  grafana:
+    image: grafana/grafana
+    container_name: grafana
+    restart: always
+    volumes:
+      - ./config/grafana:/etc/grafana
+    ports:
+      - '3000:3000'
+    depends_on:
+      - prometheus
+    environment:
+     - GF_SECURITY_ADMIN_PASSWORD:secret
diff --git a/util/journaldb/Cargo.toml b/util/journaldb/Cargo.toml
index 716899666..f3750318e 100644
--- a/util/journaldb/Cargo.toml
+++ b/util/journaldb/Cargo.toml
@@ -13,7 +13,7 @@ heapsize = "0.4"
 keccak-hasher = { path = "../keccak-hasher" }
 kvdb = "0.1"
 log = "0.4"
-memory-db = "0.11.0"
+memory-db = { path = "../../util/memory-db" }
 parking_lot = "0.7"
 fastmap = { path = "../../util/fastmap" }
 rlp = { version = "0.3.0", features = ["ethereum"] }
diff --git a/util/journaldb/src/archivedb.rs b/util/journaldb/src/archivedb.rs
index b20d7c258..10d165d06 100644
--- a/util/journaldb/src/archivedb.rs
+++ b/util/journaldb/src/archivedb.rs
@@ -17,7 +17,7 @@
 //! Disk-backed `HashDB` implementation.
 
 use std::{
-    collections::{hash_map::Entry, HashMap},
+    collections::{hash_map::Entry, BTreeMap, HashMap},
     io,
     sync::Arc,
 };
@@ -127,8 +127,8 @@ impl JournalDB for ArchiveDB {
         })
     }
 
-    fn mem_used(&self) -> usize {
-        self.overlay.mem_used()
+    fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>) {
+        sizes.insert(String::from("db_archive_overlay"), self.overlay.len());
     }
 
     fn is_empty(&self) -> bool {
diff --git a/util/journaldb/src/earlymergedb.rs b/util/journaldb/src/earlymergedb.rs
index 30b663cde..69374b898 100644
--- a/util/journaldb/src/earlymergedb.rs
+++ b/util/journaldb/src/earlymergedb.rs
@@ -17,7 +17,7 @@
 //! Disk-backed `HashDB` implementation.
 
 use std::{
-    collections::{hash_map::Entry, HashMap},
+    collections::{hash_map::Entry, BTreeMap, HashMap},
     io,
     sync::Arc,
 };
@@ -416,12 +416,14 @@ impl JournalDB for EarlyMergeDB {
         self.latest_era
     }
 
-    fn mem_used(&self) -> usize {
-        self.overlay.mem_used()
-            + match self.refs {
-                Some(ref c) => c.read().heap_size_of_children(),
-                None => 0,
-            }
+    fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>) {
+        let refs_size = match self.refs {
+            Some(ref c) => c.read().len(),
+            None => 0,
+        };
+
+        sizes.insert(String::from("db_archive_overlay"), self.overlay.len());
+        sizes.insert(String::from("db_early_merge_refs-size"), refs_size);
     }
 
     fn journal_under(&mut self, batch: &mut DBTransaction, now: u64, id: &H256) -> io::Result<u32> {
diff --git a/util/journaldb/src/overlayrecentdb.rs b/util/journaldb/src/overlayrecentdb.rs
index 086486e28..ad418068d 100644
--- a/util/journaldb/src/overlayrecentdb.rs
+++ b/util/journaldb/src/overlayrecentdb.rs
@@ -17,7 +17,7 @@
 //! `JournalDB` over in-memory overlay
 
 use std::{
-    collections::{hash_map::Entry, HashMap},
+    collections::{hash_map::Entry, BTreeMap, HashMap},
     io,
     sync::Arc,
 };
@@ -288,15 +288,25 @@ impl JournalDB for OverlayRecentDB {
         Box::new(self.clone())
     }
 
-    fn mem_used(&self) -> usize {
-        let mut mem = self.transaction_overlay.mem_used();
-        let overlay = self.journal_overlay.read();
-
-        mem += overlay.backing_overlay.mem_used();
-        mem += overlay.pending_overlay.heap_size_of_children();
-        mem += overlay.journal.heap_size_of_children();
+    fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>) {
+        sizes.insert(
+            String::from("db_overlay_recent_transactions_size"),
+            self.transaction_overlay.len(),
+        );
 
-        mem
+        let overlay = self.journal_overlay.read();
+        sizes.insert(
+            String::from("db_overlay_recent_backing_size"),
+            overlay.backing_overlay.len(),
+        );
+        sizes.insert(
+            String::from("db_overlay_recent_pending_size"),
+            overlay.pending_overlay.len(),
+        );
+        sizes.insert(
+            String::from("db_overlay_recent_journal_size"),
+            overlay.journal.len(),
+        );
     }
 
     fn journal_size(&self) -> usize {
@@ -462,6 +472,7 @@ impl JournalDB for OverlayRecentDB {
             }
         }
         journal_overlay.journal.remove(&end_era);
+        journal_overlay.backing_overlay.shrink_to_fit();
 
         if !journal_overlay.journal.is_empty() {
             trace!(target: "journaldb", "Set earliest_era to {}", end_era + 1);
diff --git a/util/journaldb/src/refcounteddb.rs b/util/journaldb/src/refcounteddb.rs
index fdc0aec19..965b90b9f 100644
--- a/util/journaldb/src/refcounteddb.rs
+++ b/util/journaldb/src/refcounteddb.rs
@@ -16,7 +16,11 @@
 
 //! Disk-backed, ref-counted `JournalDB` implementation.
 
-use std::{collections::HashMap, io, sync::Arc};
+use std::{
+    collections::{BTreeMap, HashMap},
+    io,
+    sync::Arc,
+};
 
 use super::{traits::JournalDB, LATEST_ERA_KEY};
 use ethereum_types::H256;
@@ -116,8 +120,15 @@ impl JournalDB for RefCountedDB {
         })
     }
 
-    fn mem_used(&self) -> usize {
-        self.inserts.heap_size_of_children() + self.removes.heap_size_of_children()
+    fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>) {
+        sizes.insert(
+            String::from("db_ref_counted_inserts"),
+            self.inserts.heap_size_of_children(),
+        );
+        sizes.insert(
+            String::from("db_ref_counted_removes"),
+            self.removes.heap_size_of_children(),
+        );
     }
 
     fn is_empty(&self) -> bool {
diff --git a/util/journaldb/src/traits.rs b/util/journaldb/src/traits.rs
index d634f5ebb..5473c62ae 100644
--- a/util/journaldb/src/traits.rs
+++ b/util/journaldb/src/traits.rs
@@ -22,7 +22,7 @@ use ethereum_types::H256;
 use hash_db::{AsHashDB, HashDB};
 use keccak_hasher::KeccakHasher;
 use kvdb::{self, DBTransaction, DBValue};
-use std::collections::HashMap;
+use std::collections::{BTreeMap, HashMap};
 
 /// expose keys of a hashDB for debugging or tests (slow).
 pub trait KeyedHashDB: HashDB<KeccakHasher, DBValue> {
@@ -43,7 +43,7 @@ pub trait JournalDB: KeyedHashDB {
     fn boxed_clone(&self) -> Box<dyn JournalDB>;
 
     /// Returns heap memory size used
-    fn mem_used(&self) -> usize;
+    fn get_sizes(&self, sizes: &mut BTreeMap<String, usize>);
 
     /// Returns the size of journalled state in memory.
     /// This function has a considerable speed requirement --
diff --git a/util/memory-db/.cargo_vcs_info.json b/util/memory-db/.cargo_vcs_info.json
new file mode 100644
index 000000000..5c1e0e8e9
--- /dev/null
+++ b/util/memory-db/.cargo_vcs_info.json
@@ -0,0 +1,5 @@
+{
+    "git": {
+      "sha1": "909b921151ebedf34456246dde0c7c4c3d3dcecb"
+    }
+  }
\ No newline at end of file
diff --git a/util/memory-db/Cargo.toml b/util/memory-db/Cargo.toml
new file mode 100644
index 000000000..03af7f22a
--- /dev/null
+++ b/util/memory-db/Cargo.toml
@@ -0,0 +1,33 @@
+# THIS FILE IS AUTOMATICALLY GENERATED BY CARGO
+#
+# When uploading crates to the registry Cargo will automatically
+# "normalize" Cargo.toml files for maximal compatibility
+# with all versions of Cargo and also rewrite `path` dependencies
+# to registry (e.g. crates.io) dependencies
+#
+# If you believe there's an error in this file please file an
+# issue against the rust-lang/cargo repository. If you're
+# editing this file be aware that the upstream Cargo.toml
+# will likely look very different (and much more reasonable)
+
+[package]
+name = "memory-db"
+version = "0.11.0"
+authors = ["Parity Technologies <admin@parity.io>"]
+description = "In-memory implementation of hash-db, useful for tests"
+license = "Apache-2.0"
+repository = "https://github.com/paritytech/parity-common"
+
+[[bench]]
+name = "bench"
+harness = false
+[dependencies.hash-db]
+version = "0.11.0"
+
+[dependencies.heapsize]
+version = "0.4"
+[dev-dependencies.criterion]
+version = "0.2.8"
+
+[dev-dependencies.keccak-hasher]
+version = "0.11.0"
\ No newline at end of file
diff --git a/util/memory-db/Cargo.toml.orig b/util/memory-db/Cargo.toml.orig
new file mode 100644
index 000000000..098d127d5
--- /dev/null
+++ b/util/memory-db/Cargo.toml.orig
@@ -0,0 +1,19 @@
+[package]
+name = "memory-db"
+version = "0.11.0"
+authors = ["Parity Technologies <admin@parity.io>"]
+description = "In-memory implementation of hash-db, useful for tests"
+repository = "https://github.com/paritytech/parity-common"
+license = "Apache-2.0"
+
+[dependencies]
+heapsize = "0.4"
+hash-db = { path = "../hash-db", version = "0.11.0"}
+
+[dev-dependencies]
+keccak-hasher = { path = "../test-support/keccak-hasher", version = "0.11.0"}
+criterion = "0.2.8"
+
+[[bench]]
+name = "bench"
+harness = false
\ No newline at end of file
diff --git a/util/memory-db/README.md b/util/memory-db/README.md
new file mode 100644
index 000000000..fc0c6309f
--- /dev/null
+++ b/util/memory-db/README.md
@@ -0,0 +1 @@
+MemoryDB is a reference counted memory-based [`HashDB`](https://github.com/paritytech/parity-common/tree/master/hash-db) implementation backed by a `HashMap`.
\ No newline at end of file
diff --git a/util/memory-db/benches/bench.rs b/util/memory-db/benches/bench.rs
new file mode 100644
index 000000000..a0212f435
--- /dev/null
+++ b/util/memory-db/benches/bench.rs
@@ -0,0 +1,90 @@
+// Copyright 2017, 2018 Parity Technologies
+//
+// Licensed under the Apache License, Version 2.0 (the "License");
+// you may not use this file except in compliance with the License.
+// You may obtain a copy of the License at
+//
+//     http://www.apache.org/licenses/LICENSE-2.0
+//
+// Unless required by applicable law or agreed to in writing, software
+// distributed under the License is distributed on an "AS IS" BASIS,
+// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+// See the License for the specific language governing permissions and
+// limitations under the License.
+
+#[macro_use]
+extern crate criterion;
+use criterion::{black_box, Criterion};
+criterion_group!(
+    benches,
+    instantiation,
+    compare_to_null_embedded_in_struct,
+    compare_to_null_in_const,
+    contains_with_non_null_key,
+    contains_with_null_key
+);
+criterion_main!(benches);
+
+extern crate hash_db;
+extern crate keccak_hasher;
+extern crate memory_db;
+
+use hash_db::{HashDB, Hasher};
+use keccak_hasher::KeccakHasher;
+use memory_db::MemoryDB;
+
+fn instantiation(b: &mut Criterion) {
+    b.bench_function("instantiation", |b| {
+        b.iter(|| {
+            MemoryDB::<KeccakHasher, Vec<u8>>::default();
+        })
+    });
+}
+
+fn compare_to_null_embedded_in_struct(b: &mut Criterion) {
+    struct X {
+        a_hash: <KeccakHasher as Hasher>::Out,
+    };
+    let x = X {
+        a_hash: KeccakHasher::hash(&[0u8][..]),
+    };
+    let key = KeccakHasher::hash(b"abc");
+
+    b.bench_function("compare_to_null_embedded_in_struct", move |b| {
+        b.iter(|| {
+            black_box(key == x.a_hash);
+        })
+    });
+}
+
+fn compare_to_null_in_const(b: &mut Criterion) {
+    let key = KeccakHasher::hash(b"abc");
+
+    b.bench_function("compare_to_null_in_const", move |b| {
+        b.iter(|| {
+            black_box(key == [0u8; 32]);
+        })
+    });
+}
+
+fn contains_with_non_null_key(b: &mut Criterion) {
+    let mut m = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+    let key = KeccakHasher::hash(b"abc");
+    m.insert(b"abcefghijklmnopqrstuvxyz");
+    b.bench_function("contains_with_non_null_key", move |b| {
+        b.iter(|| {
+            m.contains(&key);
+        })
+    });
+}
+
+fn contains_with_null_key(b: &mut Criterion) {
+    let mut m = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+    let null_key = KeccakHasher::hash(&[0u8][..]);
+    m.insert(b"abcefghijklmnopqrstuvxyz");
+    b.bench_function("contains_with_null_key", move |b| {
+        b.iter(|| {
+            m.contains(&null_key);
+        })
+    });
+}
diff --git a/util/memory-db/src/lib.rs b/util/memory-db/src/lib.rs
new file mode 100644
index 000000000..c7bf97eb8
--- /dev/null
+++ b/util/memory-db/src/lib.rs
@@ -0,0 +1,463 @@
+// Copyright 2017, 2018 Parity Technologies
+//
+// Licensed under the Apache License, Version 2.0 (the "License");
+// you may not use this file except in compliance with the License.
+// You may obtain a copy of the License at
+//
+//     http://www.apache.org/licenses/LICENSE-2.0
+//
+// Unless required by applicable law or agreed to in writing, software
+// distributed under the License is distributed on an "AS IS" BASIS,
+// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+// See the License for the specific language governing permissions and
+// limitations under the License.
+
+//! Reference-counted memory-based `HashDB` implementation.
+
+extern crate hash_db;
+extern crate heapsize;
+#[cfg(test)]
+extern crate keccak_hasher;
+
+use hash_db::{AsHashDB, AsPlainDB, HashDB, HashDBRef, Hasher as KeyHasher, PlainDB, PlainDBRef};
+use heapsize::HeapSizeOf;
+use std::{
+    collections::{hash_map::Entry, HashMap},
+    hash, mem,
+};
+
+// Backing `HashMap` parametrized with a `Hasher` for the keys `Hasher::Out` and the `Hasher::StdHasher`
+// as hash map builder.
+type FastMap<H, T> =
+    HashMap<<H as KeyHasher>::Out, T, hash::BuildHasherDefault<<H as KeyHasher>::StdHasher>>;
+
+/// Reference-counted memory-based `HashDB` implementation.
+///
+/// Use `new()` to create a new database. Insert items with `insert()`, remove items
+/// with `remove()`, check for existence with `contains()` and lookup a hash to derive
+/// the data with `get()`. Clear with `clear()` and purge the portions of the data
+/// that have no references with `purge()`.
+///
+/// # Example
+/// ```rust
+/// extern crate hash_db;
+/// extern crate keccak_hasher;
+/// extern crate memory_db;
+///
+/// use hash_db::{Hasher, HashDB};
+/// use keccak_hasher::KeccakHasher;
+/// use memory_db::MemoryDB;
+/// fn main() {
+///   let mut m = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+///   let d = "Hello world!".as_bytes();
+///
+///   let k = m.insert(d);
+///   assert!(m.contains(&k));
+///   assert_eq!(m.get(&k).unwrap(), d);
+///
+///   m.insert(d);
+///   assert!(m.contains(&k));
+///
+///   m.remove(&k);
+///   assert!(m.contains(&k));
+///
+///   m.remove(&k);
+///   assert!(!m.contains(&k));
+///
+///   m.remove(&k);
+///   assert!(!m.contains(&k));
+///
+///   m.insert(d);
+///   assert!(!m.contains(&k));
+
+///   m.insert(d);
+///   assert!(m.contains(&k));
+///   assert_eq!(m.get(&k).unwrap(), d);
+///
+///   m.remove(&k);
+///   assert!(!m.contains(&k));
+/// }
+/// ```
+#[derive(Clone, PartialEq)]
+pub struct MemoryDB<H: KeyHasher, T> {
+    data: FastMap<H, (T, i32)>,
+    hashed_null_node: H::Out,
+    null_node_data: T,
+}
+
+impl<'a, H, T> Default for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: From<&'a [u8]>,
+{
+    fn default() -> Self {
+        Self::from_null_node(&[0u8][..], [0u8][..].into())
+    }
+}
+
+impl<H, T> MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default,
+{
+    /// Remove an element and delete it from storage if reference count reaches zero.
+    /// If the value was purged, return the old value.
+    pub fn remove_and_purge(&mut self, key: &<H as KeyHasher>::Out) -> Option<T> {
+        if key == &self.hashed_null_node {
+            return None;
+        }
+        match self.data.entry(key.clone()) {
+            Entry::Occupied(mut entry) => {
+                if entry.get().1 == 1 {
+                    Some(entry.remove().0)
+                } else {
+                    entry.get_mut().1 -= 1;
+                    None
+                }
+            }
+            Entry::Vacant(entry) => {
+                entry.insert((T::default(), -1)); // FIXME: shouldn't it be purged?
+                None
+            }
+        }
+    }
+}
+
+impl<'a, H: KeyHasher, T> MemoryDB<H, T>
+where
+    T: From<&'a [u8]>,
+{
+    /// Create a new `MemoryDB` from a given null key/data
+    pub fn from_null_node(null_key: &'a [u8], null_node_data: T) -> Self {
+        MemoryDB {
+            data: FastMap::<H, _>::default(),
+            hashed_null_node: H::hash(null_key),
+            null_node_data,
+        }
+    }
+
+    /// Create a new `MemoryDB` from a given null key/data
+    pub fn new(data: &'a [u8]) -> Self {
+        MemoryDB {
+            data: FastMap::<H, _>::default(),
+            hashed_null_node: H::hash(data),
+            null_node_data: data.into(),
+        }
+    }
+
+    /// Returns the number of elements in the map.
+    pub fn len(&self) -> usize {
+        self.data.len()
+    }
+
+    /// Shrinks the capacity of the map as much as possible.
+    /// It will drop down as much as possible while maintaining the internal rules and possibly leaving some space in accordance with the resize policy.
+    pub fn shrink_to_fit(&mut self) {
+        self.data.shrink_to_fit();
+    }
+
+    /// Clear all data from the database.
+    ///
+    /// # Examples
+    /// ```rust
+    /// extern crate hash_db;
+    /// extern crate keccak_hasher;
+    /// extern crate memory_db;
+    ///
+    /// use hash_db::{Hasher, HashDB};
+    /// use keccak_hasher::KeccakHasher;
+    /// use memory_db::MemoryDB;
+    ///
+    /// fn main() {
+    ///   let mut m = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+    ///   let hello_bytes = "Hello world!".as_bytes();
+    ///   let hash = m.insert(hello_bytes);
+    ///   assert!(m.contains(&hash));
+    ///   m.clear();
+    ///   assert!(!m.contains(&hash));
+    /// }
+    /// ```
+    pub fn clear(&mut self) {
+        self.data.clear();
+    }
+
+    /// Purge all zero-referenced data from the database.
+    pub fn purge(&mut self) {
+        self.data.retain(|_, &mut (_, rc)| rc != 0);
+    }
+
+    /// Return the internal map of hashes to data, clearing the current state.
+    pub fn drain(&mut self) -> FastMap<H, (T, i32)> {
+        mem::replace(&mut self.data, FastMap::<H, _>::default())
+    }
+
+    /// Grab the raw information associated with a key. Returns None if the key
+    /// doesn't exist.
+    ///
+    /// Even when Some is returned, the data is only guaranteed to be useful
+    /// when the refs > 0.
+    pub fn raw(&self, key: &<H as KeyHasher>::Out) -> Option<(&T, i32)> {
+        if key == &self.hashed_null_node {
+            return Some((&self.null_node_data, 1));
+        }
+        self.data.get(key).map(|(value, count)| (value, *count))
+    }
+
+    /// Consolidate all the entries of `other` into `self`.
+    pub fn consolidate(&mut self, mut other: Self) {
+        for (key, (value, rc)) in other.drain() {
+            match self.data.entry(key) {
+                Entry::Occupied(mut entry) => {
+                    if entry.get().1 < 0 {
+                        entry.get_mut().0 = value;
+                    }
+
+                    entry.get_mut().1 += rc;
+                }
+                Entry::Vacant(entry) => {
+                    entry.insert((value, rc));
+                }
+            }
+        }
+    }
+
+    /// Get the keys in the database together with number of underlying references.
+    pub fn keys(&self) -> HashMap<H::Out, i32> {
+        self.data
+            .iter()
+            .filter_map(|(k, v)| if v.1 != 0 { Some((*k, v.1)) } else { None })
+            .collect()
+    }
+}
+
+impl<H, T> MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: HeapSizeOf,
+{
+    /// Returns the size of allocated heap memory
+    pub fn mem_used(&self) -> usize {
+        0 //self.data.heap_size_of_children()
+          // TODO Reenable above when HeapSizeOf supports arrays.
+    }
+}
+
+impl<H, T> PlainDB<H::Out, T> for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default + PartialEq<T> + for<'a> From<&'a [u8]> + Clone + Send + Sync,
+{
+    fn get(&self, key: &H::Out) -> Option<T> {
+        match self.data.get(key) {
+            Some(&(ref d, rc)) if rc > 0 => Some(d.clone()),
+            _ => None,
+        }
+    }
+
+    fn contains(&self, key: &H::Out) -> bool {
+        match self.data.get(key) {
+            Some(&(_, x)) if x > 0 => true,
+            _ => false,
+        }
+    }
+
+    fn emplace(&mut self, key: H::Out, value: T) {
+        match self.data.entry(key) {
+            Entry::Occupied(mut entry) => {
+                let &mut (ref mut old_value, ref mut rc) = entry.get_mut();
+                if *rc <= 0 {
+                    *old_value = value;
+                }
+                *rc += 1;
+            }
+            Entry::Vacant(entry) => {
+                entry.insert((value, 1));
+            }
+        }
+    }
+
+    fn remove(&mut self, key: &H::Out) {
+        match self.data.entry(*key) {
+            Entry::Occupied(mut entry) => {
+                let &mut (_, ref mut rc) = entry.get_mut();
+                *rc -= 1;
+            }
+            Entry::Vacant(entry) => {
+                entry.insert((T::default(), -1));
+            }
+        }
+    }
+}
+
+impl<H, T> PlainDBRef<H::Out, T> for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default + PartialEq<T> + for<'a> From<&'a [u8]> + Clone + Send + Sync,
+{
+    fn get(&self, key: &H::Out) -> Option<T> {
+        PlainDB::get(self, key)
+    }
+    fn contains(&self, key: &H::Out) -> bool {
+        PlainDB::contains(self, key)
+    }
+}
+
+impl<H, T> HashDB<H, T> for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default + PartialEq<T> + for<'a> From<&'a [u8]> + Clone + Send + Sync,
+{
+    fn get(&self, key: &H::Out) -> Option<T> {
+        if key == &self.hashed_null_node {
+            return Some(self.null_node_data.clone());
+        }
+
+        PlainDB::get(self, key)
+    }
+
+    fn contains(&self, key: &H::Out) -> bool {
+        if key == &self.hashed_null_node {
+            return true;
+        }
+
+        PlainDB::contains(self, key)
+    }
+
+    fn emplace(&mut self, key: H::Out, value: T) {
+        if value == self.null_node_data {
+            return;
+        }
+
+        PlainDB::emplace(self, key, value)
+    }
+
+    fn insert(&mut self, value: &[u8]) -> H::Out {
+        if T::from(value) == self.null_node_data {
+            return self.hashed_null_node.clone();
+        }
+
+        let key = H::hash(value);
+        PlainDB::emplace(self, key.clone(), value.into());
+
+        key
+    }
+
+    fn remove(&mut self, key: &H::Out) {
+        if key == &self.hashed_null_node {
+            return;
+        }
+
+        PlainDB::remove(self, key)
+    }
+}
+
+impl<H, T> HashDBRef<H, T> for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default + PartialEq<T> + for<'a> From<&'a [u8]> + Clone + Send + Sync,
+{
+    fn get(&self, key: &H::Out) -> Option<T> {
+        HashDB::get(self, key)
+    }
+    fn contains(&self, key: &H::Out) -> bool {
+        HashDB::contains(self, key)
+    }
+}
+
+impl<H, T> AsPlainDB<H::Out, T> for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default + PartialEq<T> + for<'a> From<&'a [u8]> + Clone + Send + Sync,
+{
+    fn as_plain_db(&self) -> &dyn PlainDB<H::Out, T> {
+        self
+    }
+    fn as_plain_db_mut(&mut self) -> &mut dyn PlainDB<H::Out, T> {
+        self
+    }
+}
+
+impl<H, T> AsHashDB<H, T> for MemoryDB<H, T>
+where
+    H: KeyHasher,
+    T: Default + PartialEq<T> + for<'a> From<&'a [u8]> + Clone + Send + Sync,
+{
+    fn as_hash_db(&self) -> &dyn HashDB<H, T> {
+        self
+    }
+    fn as_hash_db_mut(&mut self) -> &mut dyn HashDB<H, T> {
+        self
+    }
+}
+
+#[cfg(test)]
+mod tests {
+    use super::{HashDB, KeyHasher, MemoryDB};
+    use keccak_hasher::KeccakHasher;
+
+    #[test]
+    fn memorydb_remove_and_purge() {
+        let hello_bytes = b"Hello world!";
+        let hello_key = KeccakHasher::hash(hello_bytes);
+
+        let mut m = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+        m.remove(&hello_key);
+        assert_eq!(m.raw(&hello_key).unwrap().1, -1);
+        m.purge();
+        assert_eq!(m.raw(&hello_key).unwrap().1, -1);
+        m.insert(hello_bytes);
+        assert_eq!(m.raw(&hello_key).unwrap().1, 0);
+        m.purge();
+        assert_eq!(m.raw(&hello_key), None);
+
+        let mut m = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+        assert!(m.remove_and_purge(&hello_key).is_none());
+        assert_eq!(m.raw(&hello_key).unwrap().1, -1);
+        m.insert(hello_bytes);
+        m.insert(hello_bytes);
+        assert_eq!(m.raw(&hello_key).unwrap().1, 1);
+        assert_eq!(&*m.remove_and_purge(&hello_key).unwrap(), hello_bytes);
+        assert_eq!(m.raw(&hello_key), None);
+        assert!(m.remove_and_purge(&hello_key).is_none());
+    }
+
+    #[test]
+    fn consolidate() {
+        let mut main = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+        let mut other = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+        let remove_key = other.insert(b"doggo");
+        main.remove(&remove_key);
+
+        let insert_key = other.insert(b"arf");
+        main.emplace(insert_key, "arf".as_bytes().to_vec());
+
+        let negative_remove_key = other.insert(b"negative");
+        other.remove(&negative_remove_key); // ref cnt: 0
+        other.remove(&negative_remove_key); // ref cnt: -1
+        main.remove(&negative_remove_key); // ref cnt: -1
+
+        main.consolidate(other);
+
+        let overlay = main.drain();
+
+        assert_eq!(
+            overlay.get(&remove_key).unwrap(),
+            &("doggo".as_bytes().to_vec(), 0)
+        );
+        assert_eq!(
+            overlay.get(&insert_key).unwrap(),
+            &("arf".as_bytes().to_vec(), 2)
+        );
+        assert_eq!(
+            overlay.get(&negative_remove_key).unwrap(),
+            &("negative".as_bytes().to_vec(), -2)
+        );
+    }
+
+    #[test]
+    fn default_works() {
+        let mut db = MemoryDB::<KeccakHasher, Vec<u8>>::default();
+        let hashed_null_node = KeccakHasher::hash(&[0u8][..]);
+        assert_eq!(db.insert(&[0u8][..]), hashed_null_node);
+    }
+}
diff --git a/util/stats/Cargo.toml b/util/stats/Cargo.toml
index 9997c7846..328b6f7b2 100644
--- a/util/stats/Cargo.toml
+++ b/util/stats/Cargo.toml
@@ -5,3 +5,4 @@ authors = ["Parity Technologies <admin@parity.io>"]
 
 [dependencies]
 log = "0.4"
+prometheus = "0.9.0"
diff --git a/util/stats/src/lib.rs b/util/stats/src/lib.rs
index b3c547b51..38def7ee9 100644
--- a/util/stats/src/lib.rs
+++ b/util/stats/src/lib.rs
@@ -19,10 +19,47 @@
 use std::{
     iter::FromIterator,
     ops::{Add, Deref, Div, Sub},
+    time::Instant,
 };
 
 #[macro_use]
 extern crate log;
+pub extern crate prometheus;
+
+/// Implements a prometheus metrics collector
+pub trait PrometheusMetrics {
+    fn prometheus_metrics(&self, registry: &mut prometheus::Registry);
+}
+
+/// Adds a new prometheus counter with the specified value
+pub fn prometheus_counter(reg: &mut prometheus::Registry, name: &str, help: &str, value: i64) {
+    let c = prometheus::IntCounter::new(name, help).expect("name and help must be non-empty");
+    c.inc_by(value);
+    reg.register(Box::new(c))
+        .expect("prometheus identifiers must be unique");
+}
+
+/// Adds a new prometheus gauge with the specified gauge
+pub fn prometheus_gauge(reg: &mut prometheus::Registry, name: &str, help: &str, value: i64) {
+    let g = prometheus::IntGauge::new(name, help).expect("name and help must be non-empty");
+    g.set(value);
+    reg.register(Box::new(g))
+        .expect("prometheus identifiers must be are unique");
+}
+
+/// Adds a new prometheus counter with the time spent in running the specified function
+pub fn prometheus_optime<F: Fn() -> T, T>(r: &mut prometheus::Registry, name: &str, f: &F) -> T {
+    let start = Instant::now();
+    let t = f();
+    let elapsed = start.elapsed();
+    prometheus_gauge(
+        r,
+        &format!("optime_{}", name),
+        &format!("Time to perform {}", name),
+        elapsed.as_millis() as i64,
+    );
+    t
+}
 
 /// Sorted corpus of data.
 #[derive(Debug, Clone, PartialEq)]
