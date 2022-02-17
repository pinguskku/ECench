commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
commit c5aed5bab1de7ac96946b0d4fcada5ed1cbf5c84
Author: adria0 <adria@codecontext.io>
Date:   Wed Jul 29 11:00:04 2020 +0200

    Fix warnings: unnecessary mut

diff --git a/ethcore/evm/src/interpreter/mod.rs b/ethcore/evm/src/interpreter/mod.rs
index f1c03c0fd..082dcd33b 100644
--- a/ethcore/evm/src/interpreter/mod.rs
+++ b/ethcore/evm/src/interpreter/mod.rs
@@ -1481,7 +1481,7 @@ mod tests {
         ext.tracing = true;
 
         let gas_left = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
         };
 
@@ -1503,7 +1503,7 @@ mod tests {
         ext.tracing = true;
 
         let err = {
-            let mut vm = interpreter(params, &ext);
+            let vm = interpreter(params, &ext);
             test_finalize(vm.exec(&mut ext).ok().unwrap())
                 .err()
                 .unwrap()
diff --git a/ethcore/evm/src/tests.rs b/ethcore/evm/src/tests.rs
index 4df52cbb1..fb812b557 100644
--- a/ethcore/evm/src/tests.rs
+++ b/ethcore/evm/src/tests.rs
@@ -44,7 +44,7 @@ fn test_add(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -68,7 +68,7 @@ fn test_sha3(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -92,7 +92,7 @@ fn test_address(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -118,7 +118,7 @@ fn test_origin(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -174,7 +174,7 @@ fn test_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -238,7 +238,7 @@ fn test_extcodecopy(factory: super::Factory) {
     ext.codes.insert(sender, Arc::new(sender_code));
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -262,7 +262,7 @@ fn test_log_empty(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -294,7 +294,7 @@ fn test_log_sender(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -328,7 +328,7 @@ fn test_blockhash(factory: super::Factory) {
     ext.blockhashes.insert(U256::zero(), blockhash.clone());
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -352,7 +352,7 @@ fn test_calldataload(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -376,7 +376,7 @@ fn test_author(factory: super::Factory) {
     ext.info.author = author;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -400,7 +400,7 @@ fn test_timestamp(factory: super::Factory) {
     ext.info.timestamp = timestamp;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -424,7 +424,7 @@ fn test_number(factory: super::Factory) {
     ext.info.number = number;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -448,7 +448,7 @@ fn test_difficulty(factory: super::Factory) {
     ext.info.difficulty = difficulty;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -472,7 +472,7 @@ fn test_gas_limit(factory: super::Factory) {
     ext.info.gas_limit = gas_limit;
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -494,7 +494,7 @@ fn test_mul(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -516,7 +516,7 @@ fn test_sub(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -538,7 +538,7 @@ fn test_div(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -560,7 +560,7 @@ fn test_div_zero(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -584,7 +584,7 @@ fn test_mod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -613,7 +613,7 @@ fn test_smod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -642,7 +642,7 @@ fn test_sdiv(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -671,7 +671,7 @@ fn test_exp(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -705,7 +705,7 @@ fn test_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -744,7 +744,7 @@ fn test_signed_comparison(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -783,7 +783,7 @@ fn test_bitops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -832,7 +832,7 @@ fn test_addmod_mulmod(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -869,7 +869,7 @@ fn test_byte(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -896,7 +896,7 @@ fn test_signextend(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -924,7 +924,7 @@ fn test_badinstruction_int() {
     let mut ext = FakeExt::new();
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -944,7 +944,7 @@ fn test_pop(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -970,7 +970,7 @@ fn test_extops(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1019,7 +1019,7 @@ fn test_jumps(factory: super::Factory) {
     let mut ext = FakeExt::new();
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1055,7 +1055,7 @@ fn test_calls(factory: super::Factory) {
     };
 
     let gas_left = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1102,7 +1102,7 @@ fn test_create_in_staticcall(factory: super::Factory) {
     ext.is_static = true;
 
     let err = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap_err()
     };
 
@@ -1414,7 +1414,7 @@ fn push_two_pop_one_constantinople_test(
     let mut ext = FakeExt::new_constantinople();
 
     let _ = {
-        let mut vm = factory.create(params, ext.schedule(), ext.depth());
+        let vm = factory.create(params, ext.schedule(), ext.depth());
         test_finalize(vm.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 73428c4d8..870a314a1 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -302,7 +302,7 @@ impl Importer {
         ) = {
             let mut imported_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut invalid_blocks = HashSet::new();
-            let mut proposed_blocks = Vec::with_capacity(max_blocks_to_import);
+            let proposed_blocks = Vec::with_capacity(max_blocks_to_import);
             let mut import_results = Vec::with_capacity(max_blocks_to_import);
 
             let _import_lock = self.import_lock.lock();
diff --git a/ethcore/src/engines/clique/mod.rs b/ethcore/src/engines/clique/mod.rs
index 696a93c14..b924c9198 100644
--- a/ethcore/src/engines/clique/mod.rs
+++ b/ethcore/src/engines/clique/mod.rs
@@ -294,7 +294,7 @@ impl Clique {
 						"Back-filling block state. last_checkpoint_number: {}, target: {}({}).",
 						last_checkpoint_number, header.number(), header.hash());
 
-                let mut chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
+                let chain: &mut VecDeque<Header> = &mut VecDeque::with_capacity(
                     (header.number() - last_checkpoint_number + 1) as usize,
                 );
 
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 4eefec67c..dfd33e4f5 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -308,7 +308,7 @@ impl Engine<EthereumMachine> for Arc<Ethash> {
                 let n_uncles = block.uncles.len();
 
                 // Bestow block rewards.
-                let mut result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
+                let result_block_reward = reward + reward.shr(5) * U256::from(n_uncles);
 
                 rewards.push((author, RewardKind::Author, result_block_reward));
 
diff --git a/ethcore/src/json_tests/executive.rs b/ethcore/src/json_tests/executive.rs
index dd9b1ab7e..f02c83e42 100644
--- a/ethcore/src/json_tests/executive.rs
+++ b/ethcore/src/json_tests/executive.rs
@@ -325,7 +325,7 @@ fn do_json_test_for<H: FnMut(&str, HookType)>(
                 &mut tracer,
                 &mut vm_tracer,
             ));
-            let mut evm = vm_factory.create(params, &schedule, 0);
+            let evm = vm_factory.create(params, &schedule, 0);
             let res = evm
                 .exec(&mut ex)
                 .ok()
diff --git a/ethcore/sync/src/block_sync.rs b/ethcore/sync/src/block_sync.rs
index 91294ce96..f55157a1f 100644
--- a/ethcore/sync/src/block_sync.rs
+++ b/ethcore/sync/src/block_sync.rs
@@ -911,13 +911,13 @@ mod tests {
         let mut parent_hash = H256::zero();
         for i in 0..4 {
             // Construct the block body
-            let mut uncles = if i > 0 {
+            let uncles = if i > 0 {
                 encode_list(&[dummy_header(i - 1, H256::random())])
             } else {
                 ::rlp::EMPTY_LIST_RLP.to_vec()
             };
 
-            let mut txs = encode_list(&[dummy_signed_tx()]);
+            let txs = encode_list(&[dummy_signed_tx()]);
             let tx_root = ordered_trie_root(Rlp::new(&txs).iter().map(|r| r.as_raw()));
 
             let mut rlp = RlpStream::new_list(2);
@@ -988,7 +988,7 @@ mod tests {
             //
             // The RLP-encoded integers are clearly not receipts, but the BlockDownloader treats
             // all receipts as byte blobs, so it does not matter.
-            let mut receipts_rlp = if i < 2 {
+            let receipts_rlp = if i < 2 {
                 encode_list(&[0u32])
             } else {
                 encode_list(&[i as u32])
diff --git a/ethcore/wasm/src/tests.rs b/ethcore/wasm/src/tests.rs
index a79491be6..ae1b3fa97 100644
--- a/ethcore/wasm/src/tests.rs
+++ b/ethcore/wasm/src/tests.rs
@@ -48,7 +48,7 @@ macro_rules! reqrep_test {
         fake_ext.info = $info;
         fake_ext.blockhashes = $block_hashes;
 
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         interpreter
             .exec(&mut fake_ext)
             .ok()
@@ -91,7 +91,7 @@ fn empty() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -120,7 +120,7 @@ fn logger() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -195,7 +195,7 @@ fn identity() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -238,7 +238,7 @@ fn dispersion() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -271,7 +271,7 @@ fn suicide_not() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -313,7 +313,7 @@ fn suicide() {
     let mut ext = FakeExt::new().with_wasm();
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -345,7 +345,7 @@ fn create() {
     ext.schedule.wasm.as_mut().unwrap().have_create2 = true;
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -414,7 +414,7 @@ fn call_msg() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -471,7 +471,7 @@ fn call_msg_gasleft() {
         .insert(receiver.clone(), U256::from(10000000000u64));
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -522,7 +522,7 @@ fn call_code() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -578,7 +578,7 @@ fn call_static() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -627,7 +627,7 @@ fn realloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -659,7 +659,7 @@ fn alloc() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -699,7 +699,7 @@ fn storage_read() {
     );
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -735,7 +735,7 @@ fn keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -883,7 +883,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -905,7 +905,7 @@ fn storage_metering() {
     ]);
 
     let gas_left = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         test_finalize(interpreter.exec(&mut ext).ok().unwrap()).unwrap()
     };
 
@@ -1064,7 +1064,7 @@ fn embedded_keccak() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
@@ -1105,7 +1105,7 @@ fn events() {
     let mut ext = FakeExt::new().with_wasm();
 
     let (gas_left, result) = {
-        let mut interpreter = wasm_interpreter(params);
+        let interpreter = wasm_interpreter(params);
         let result = interpreter
             .exec(&mut ext)
             .ok()
diff --git a/parity/informant.rs b/parity/informant.rs
index b2870eb6d..e442925eb 100644
--- a/parity/informant.rs
+++ b/parity/informant.rs
@@ -282,7 +282,7 @@ impl<T: InformantData> Informant<T> {
         let elapsed = now.duration_since(*self.last_tick.read());
 
         let (client_report, full_report) = {
-            let mut last_report = self.last_report.lock();
+            let last_report = self.last_report.lock();
             let full_report = self.target.report();
             let diffed = full_report.client_report.clone() - &*last_report;
             (diffed, full_report)
diff --git a/rpc/src/v1/helpers/dispatch/prospective_signer.rs b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
index b3a25a047..8236e2200 100644
--- a/rpc/src/v1/helpers/dispatch/prospective_signer.rs
+++ b/rpc/src/v1/helpers/dispatch/prospective_signer.rs
@@ -137,7 +137,7 @@ impl<P: PostSign> Future for ProspectiveSigner<P> {
                     );
                 }
                 WaitForPostSign => {
-                    if let Some(mut fut) = self.post_sign_future.as_mut() {
+                    if let Some(fut) = self.post_sign_future.as_mut() {
                         match fut.poll()? {
                             Async::Ready(item) => {
                                 let nonce = self.ready.take().expect(
diff --git a/whisper/src/rpc/crypto.rs b/whisper/src/rpc/crypto.rs
index 081fb6c03..c14bb7f1d 100644
--- a/whisper/src/rpc/crypto.rs
+++ b/whisper/src/rpc/crypto.rs
@@ -79,7 +79,7 @@ impl EncryptionInstance {
         match self.0 {
             EncryptionInner::AES(key, nonce, encode) => match encode {
                 AesEncode::AppendedNonce => {
-                    let mut enc = Encryptor::aes_256_gcm(&*key).ok()?;
+                    let enc = Encryptor::aes_256_gcm(&*key).ok()?;
                     let mut buf = enc.encrypt(&nonce, plain.to_vec()).ok()?;
                     buf.extend(&nonce[..]);
                     Some(buf)
