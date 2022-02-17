commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
commit 629b480d60845f823356da3e16a3838eee94721a
Author: debris <marek.kotewicz@gmail.com>
Date:   Thu Jan 28 21:15:37 2016 +0100

    reduce max vm depth per thread to 64

diff --git a/src/executive.rs b/src/executive.rs
index b21026835..b113363fd 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -10,7 +10,7 @@ use crossbeam;
 /// Max depth to avoid stack overflow (when it's reached we start a new thread with VM)
 /// TODO [todr] We probably need some more sophisticated calculations here (limit on my machine 132)
 /// Maybe something like here: https://github.com/ethereum/libethereum/blob/4db169b8504f2b87f7d5a481819cfb959fc65f6c/libethereum/ExtVM.cpp
-const MAX_VM_DEPTH_FOR_THREAD: usize = 128;
+const MAX_VM_DEPTH_FOR_THREAD: usize = 64;
 
 /// Returns new address created from address and given nonce.
 pub fn contract_address(address: &Address, nonce: &U256) -> Address {
