commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
commit 9062771209e913b9221a5ac6c4cfb8374c1cf741
Author: debris <marek.kotewicz@gmail.com>
Date:   Sat Jan 16 17:06:15 2016 +0100

    fixed review issues: add_sstore_refund -> inc_sstore_refund, sstore_refunds_count -> sstore_clears_count. Also removed all unnecessary copying of transaction code/data.

diff --git a/src/evm/evm.rs b/src/evm/evm.rs
index fd6e59f6e..cb6626d75 100644
--- a/src/evm/evm.rs
+++ b/src/evm/evm.rs
@@ -25,5 +25,5 @@ pub type Result = result::Result<U256, Error>;
 /// Evm interface.
 pub trait Evm {
 	/// This function should be used to execute transaction.
-	fn exec(&self, params: &ActionParams, ext: &mut Ext) -> Result;
+	fn exec(&self, params: ActionParams, ext: &mut Ext) -> Result;
 }
diff --git a/src/evm/ext.rs b/src/evm/ext.rs
index b0a93d662..bc03b2fe1 100644
--- a/src/evm/ext.rs
+++ b/src/evm/ext.rs
@@ -87,5 +87,5 @@ pub trait Ext {
 	fn depth(&self) -> usize;
 
 	/// Increments sstore refunds count by 1.
-	fn add_sstore_refund(&mut self);
+	fn inc_sstore_refund(&mut self);
 }
diff --git a/src/evm/jit.rs b/src/evm/jit.rs
index 9aee82e34..af0aad040 100644
--- a/src/evm/jit.rs
+++ b/src/evm/jit.rs
@@ -3,43 +3,6 @@ use common::*;
 use evmjit;
 use evm;
 
-/// Ethcore representation of evmjit runtime data.
-struct RuntimeData {
-	gas: U256,
-	gas_price: U256,
-	call_data: Vec<u8>,
-	address: Address,
-	caller: Address,
-	origin: Address,
-	call_value: U256,
-	author: Address,
-	difficulty: U256,
-	gas_limit: U256,
-	number: u64,
-	timestamp: u64,
-	code: Vec<u8>
-}
-
-impl RuntimeData {
-	fn new() -> RuntimeData {
-		RuntimeData {
-			gas: U256::zero(),
-			gas_price: U256::zero(),
-			call_data: vec![],
-			address: Address::new(),
-			caller: Address::new(),
-			origin: Address::new(),
-			call_value: U256::zero(),
-			author: Address::new(),
-			difficulty: U256::zero(),
-			gas_limit: U256::zero(),
-			number: 0,
-			timestamp: 0,
-			code: vec![]
-		}
-	}
-}
-
 /// Should be used to convert jit types to ethcore
 trait FromJit<T>: Sized {
 	fn from_jit(input: T) -> Self;
@@ -126,33 +89,6 @@ impl IntoJit<evmjit::H256> for Address {
 	}
 }
 
-impl IntoJit<evmjit::RuntimeDataHandle> for RuntimeData {
-	fn into_jit(self) -> evmjit::RuntimeDataHandle {
-		let mut data = evmjit::RuntimeDataHandle::new();
-		assert!(self.gas <= U256::from(u64::max_value()), "evmjit gas must be lower than 2 ^ 64");
-		assert!(self.gas_price <= U256::from(u64::max_value()), "evmjit gas_price must be lower than 2 ^ 64");
-		data.gas = self.gas.low_u64() as i64;
-		data.gas_price = self.gas_price.low_u64() as i64;
-		data.call_data = self.call_data.as_ptr();
-		data.call_data_size = self.call_data.len() as u64;
-		mem::forget(self.call_data);
-		data.address = self.address.into_jit();
-		data.caller = self.caller.into_jit();
-		data.origin = self.origin.into_jit();
-		data.call_value = self.call_value.into_jit();
-		data.author = self.author.into_jit();
-		data.difficulty = self.difficulty.into_jit();
-		data.gas_limit = self.gas_limit.into_jit();
-		data.number = self.number;
-		data.timestamp = self.timestamp as i64;
-		data.code = self.code.as_ptr();
-		data.code_size = self.code.len() as u64;
-		data.code_hash = self.code.sha3().into_jit();
-		mem::forget(self.code);
-		data
-	}
-}
-
 /// Externalities adapter. Maps callbacks from evmjit to externalities trait.
 /// 
 /// Evmjit doesn't have to know about children execution failures. 
@@ -186,7 +122,7 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 		let old_value = self.ext.storage_at(&key);
 		// if SSTORE nonzero -> zero, increment refund count
 		if !old_value.is_zero() && value.is_zero() {
-			self.ext.add_sstore_refund();
+			self.ext.inc_sstore_refund();
 		}
 		self.ext.set_storage(key, value);
 	}
@@ -344,27 +280,39 @@ impl<'a> evmjit::Ext for ExtAdapter<'a> {
 pub struct JitEvm;
 
 impl evm::Evm for JitEvm {
-	fn exec(&self, params: &ActionParams, ext: &mut evm::Ext) -> evm::Result {
+	fn exec(&self, params: ActionParams, ext: &mut evm::Ext) -> evm::Result {
 		// Dirty hack. This is unsafe, but we interact with ffi, so it's justified.
 		let ext_adapter: ExtAdapter<'static> = unsafe { ::std::mem::transmute(ExtAdapter::new(ext, params.address.clone())) };
 		let mut ext_handle = evmjit::ExtHandle::new(ext_adapter);
-		let mut data = RuntimeData::new();
-		data.gas = params.gas;
-		data.gas_price = params.gas_price;
-		data.call_data = params.data.clone().unwrap_or(vec![]);
-		data.address = params.address.clone();
-		data.caller = params.sender.clone();
-		data.origin = params.origin.clone();
-		data.call_value = params.value;
-		data.code = params.code.clone().unwrap_or(vec![]);
-
-		data.author = ext.env_info().author.clone();
-		data.difficulty = ext.env_info().difficulty;
-		data.gas_limit = ext.env_info().gas_limit;
+		assert!(params.gas <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+		assert!(params.gas_price <= U256::from(i64::max_value() as u64), "evmjit max gas is 2 ^ 63");
+
+		let call_data = params.data.unwrap_or(vec![]);
+		let code = params.code.unwrap_or(vec![]);
+
+		let mut data = evmjit::RuntimeDataHandle::new();
+		data.gas = params.gas.low_u64() as i64;
+		data.gas_price = params.gas_price.low_u64() as i64;
+		data.call_data = call_data.as_ptr();
+		data.call_data_size = call_data.len() as u64;
+		mem::forget(call_data);
+		data.code = code.as_ptr();
+		data.code_size = code.len() as u64;
+		data.code_hash = code.sha3().into_jit();
+		mem::forget(code);
+		data.address = params.address.into_jit();
+		data.caller = params.sender.into_jit();
+		data.origin = params.origin.into_jit();
+		data.call_value = params.value.into_jit();
+
+		data.author = ext.env_info().author.clone().into_jit();
+		data.difficulty = ext.env_info().difficulty.into_jit();
+		data.gas_limit = ext.env_info().gas_limit.into_jit();
 		data.number = ext.env_info().number;
-		data.timestamp = ext.env_info().timestamp;
-		
-		let mut context = unsafe { evmjit::ContextHandle::new(data.into_jit(), &mut ext_handle) };
+		// don't really know why jit timestamp is int..
+		data.timestamp = ext.env_info().timestamp as i64;
+
+		let mut context = unsafe { evmjit::ContextHandle::new(data, &mut ext_handle) };
 		let res = context.exec();
 		
 		match res {
diff --git a/src/evm/tests.rs b/src/evm/tests.rs
index 215b7ea85..d53de01b3 100644
--- a/src/evm/tests.rs
+++ b/src/evm/tests.rs
@@ -91,7 +91,7 @@ impl Ext for FakeExt {
 		unimplemented!();
 	}
 
-	fn add_sstore_refund(&mut self) {
+	fn inc_sstore_refund(&mut self) {
 		unimplemented!();
 	}
 }
@@ -109,7 +109,7 @@ fn test_add() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_988));
@@ -129,7 +129,7 @@ fn test_sha3() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_961));
@@ -149,7 +149,7 @@ fn test_address() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -171,7 +171,7 @@ fn test_origin() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -193,7 +193,7 @@ fn test_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -228,7 +228,7 @@ fn test_extcodecopy() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_935));
@@ -248,7 +248,7 @@ fn test_log_empty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(99_619));
@@ -280,7 +280,7 @@ fn test_log_sender() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(98_974));
@@ -305,7 +305,7 @@ fn test_blockhash() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_974));
@@ -327,7 +327,7 @@ fn test_calldataload() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_991));
@@ -348,7 +348,7 @@ fn test_author() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -368,7 +368,7 @@ fn test_timestamp() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -388,7 +388,7 @@ fn test_number() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -408,7 +408,7 @@ fn test_difficulty() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
@@ -428,7 +428,7 @@ fn test_gas_limit() {
 
 	let gas_left = {
 		let vm = Factory::create();
-		vm.exec(&params, &mut ext).unwrap()
+		vm.exec(params, &mut ext).unwrap()
 	};
 
 	assert_eq!(gas_left, U256::from(79_995));
diff --git a/src/executive.rs b/src/executive.rs
index 30c5f0f05..dd83ba44c 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -75,8 +75,8 @@ impl<'a> Executive<'a> {
 	}
 
 	/// Creates `Externalities` from `Executive`.
-	pub fn to_externalities<'_>(&'_ mut self, params: &'_ ActionParams, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
-		Externalities::new(self.state, self.info, self.engine, self.depth, params, substate, output)
+	pub fn to_externalities<'_>(&'_ mut self, origin_info: OriginInfo, substate: &'_ mut Substate, output: OutputPolicy<'_>) -> Externalities {
+		Externalities::new(self.state, self.info, self.engine, self.depth, origin_info, substate, output)
 	}
 
 	/// This funtion should be used to execute transaction.
@@ -137,7 +137,7 @@ impl<'a> Executive<'a> {
 					code: Some(t.data.clone()),
 					data: None,
 				};
-				self.create(&params, &mut substate)
+				self.create(params, &mut substate)
 			},
 			&Action::Call(ref address) => {
 				let params = ActionParams {
@@ -153,7 +153,7 @@ impl<'a> Executive<'a> {
 				};
 				// TODO: move output upstream
 				let mut out = vec![];
-				self.call(&params, &mut substate, BytesRef::Flexible(&mut out))
+				self.call(params, &mut substate, BytesRef::Flexible(&mut out))
 			}
 		};
 
@@ -165,7 +165,7 @@ impl<'a> Executive<'a> {
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate and the output.
 	/// Returns either gas_left or `evm::Error`.
-	pub fn call(&mut self, params: &ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
+	pub fn call(&mut self, params: ActionParams, substate: &mut Substate, mut output: BytesRef) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -198,12 +198,12 @@ impl<'a> Executive<'a> {
 			let mut unconfirmed_substate = Substate::new();
 
 			let res = {
-				let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::Return(output));
+				let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::Return(output));
 				let evm = Factory::create();
-				evm.exec(&params, &mut ext)
+				evm.exec(params, &mut ext)
 			};
 
-			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_refunds_count);
+			trace!("exec: sstore-clears={}\n", unconfirmed_substate.sstore_clears_count);
 			trace!("exec: substate={:?}; unconfirmed_substate={:?}\n", substate, unconfirmed_substate);
 			self.enact_result(&res, substate, unconfirmed_substate, backup);
 			trace!("exec: new substate={:?}\n", substate);
@@ -217,7 +217,7 @@ impl<'a> Executive<'a> {
 	/// Creates contract with given contract params.
 	/// NOTE. It does not finalize the transaction (doesn't do refunds, nor suicides).
 	/// Modifies the substate.
-	pub fn create(&mut self, params: &ActionParams, substate: &mut Substate) -> evm::Result {
+	pub fn create(&mut self, params: ActionParams, substate: &mut Substate) -> evm::Result {
 		// backup used in case of running out of gas
 		let backup = self.state.clone();
 
@@ -231,9 +231,9 @@ impl<'a> Executive<'a> {
 		self.state.transfer_balance(&params.sender, &params.address, &params.value);
 
 		let res = {
-			let mut ext = self.to_externalities(params, &mut unconfirmed_substate, OutputPolicy::InitContract);
+			let mut ext = self.to_externalities(OriginInfo::from(&params), &mut unconfirmed_substate, OutputPolicy::InitContract);
 			let evm = Factory::create();
-			evm.exec(&params, &mut ext)
+			evm.exec(params, &mut ext)
 		};
 		self.enact_result(&res, substate, unconfirmed_substate, backup);
 		res
@@ -244,7 +244,7 @@ impl<'a> Executive<'a> {
 		let schedule = self.engine.schedule(self.info);
 
 		// refunds from SSTORE nonzero -> zero
-		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_refunds_count;
+		let sstore_refunds = U256::from(schedule.sstore_refund_gas) * substate.sstore_clears_count;
 		// refunds from contract suicides
 		let suicide_refunds = U256::from(schedule.suicide_refund_gas) * U256::from(substate.suicides.len());
 		let refunds_bound = sstore_refunds + suicide_refunds;
@@ -359,7 +359,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(79_975));
@@ -417,7 +417,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -470,7 +470,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap()
+			ex.create(params, &mut substate).unwrap()
 		};
 		
 		assert_eq!(gas_left, U256::from(62_976));
@@ -521,7 +521,7 @@ mod tests {
 
 		{
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.create(&params, &mut substate).unwrap();
+			ex.create(params, &mut substate).unwrap();
 		}
 		
 		assert_eq!(substate.contracts_created.len(), 1);
@@ -581,7 +581,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(73_237));
@@ -625,7 +625,7 @@ mod tests {
 
 		let gas_left = {
 			let mut ex = Executive::new(&mut state, &info, &engine);
-			ex.call(&params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
+			ex.call(params, &mut substate, BytesRef::Fixed(&mut [])).unwrap()
 		};
 
 		assert_eq!(gas_left, U256::from(59_870));
diff --git a/src/externalities.rs b/src/externalities.rs
index b3a7e94f9..38aecd7ef 100644
--- a/src/externalities.rs
+++ b/src/externalities.rs
@@ -15,13 +15,32 @@ pub enum OutputPolicy<'a> {
 	InitContract
 }
 
+/// Things that externalities need to know about
+/// transaction origin.
+pub struct OriginInfo {
+	address: Address,
+	origin: Address,
+	gas_price: U256
+}
+
+impl OriginInfo {
+	/// Populates origin info from action params.
+	pub fn from(params: &ActionParams) -> Self {
+		OriginInfo {
+			address: params.address.clone(),
+			origin: params.origin.clone(),
+			gas_price: params.gas_price.clone()
+		}
+	}
+}
+
 /// Implementation of evm Externalities.
 pub struct Externalities<'a> {
 	state: &'a mut State,
-	info: &'a EnvInfo,
+	env_info: &'a EnvInfo,
 	engine: &'a Engine,
 	depth: usize,
-	params: &'a ActionParams,
+	origin_info: OriginInfo,
 	substate: &'a mut Substate,
 	schedule: Schedule,
 	output: OutputPolicy<'a>
@@ -30,20 +49,20 @@ pub struct Externalities<'a> {
 impl<'a> Externalities<'a> {
 	/// Basic `Externalities` constructor.
 	pub fn new(state: &'a mut State, 
-			   info: &'a EnvInfo, 
+			   env_info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
 			   output: OutputPolicy<'a>) -> Self {
 		Externalities {
 			state: state,
-			info: info,
+			env_info: env_info,
 			engine: engine,
 			depth: depth,
-			params: params,
+			origin_info: origin_info,
 			substate: substate,
-			schedule: engine.schedule(info),
+			schedule: engine.schedule(env_info),
 			output: output
 		}
 	}
@@ -51,11 +70,11 @@ impl<'a> Externalities<'a> {
 
 impl<'a> Ext for Externalities<'a> {
 	fn storage_at(&self, key: &H256) -> H256 {
-		self.state.storage_at(&self.params.address, key)
+		self.state.storage_at(&self.origin_info.address, key)
 	}
 
 	fn set_storage(&mut self, key: H256, value: H256) {
-		self.state.set_storage(&self.params.address, key, value)
+		self.state.set_storage(&self.origin_info.address, key, value)
 	}
 
 	fn exists(&self, address: &Address) -> bool {
@@ -67,15 +86,15 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn blockhash(&self, number: &U256) -> H256 {
-		match *number < U256::from(self.info.number) && number.low_u64() >= cmp::max(256, self.info.number) - 256 {
+		match *number < U256::from(self.env_info.number) && number.low_u64() >= cmp::max(256, self.env_info.number) - 256 {
 			true => {
-				let index = self.info.number - number.low_u64() - 1;
-				let r = self.info.last_hashes[index as usize].clone();
-				trace!("ext: blockhash({}) -> {} self.info.number={}\n", number, r, self.info.number);
+				let index = self.env_info.number - number.low_u64() - 1;
+				let r = self.env_info.last_hashes[index as usize].clone();
+				trace!("ext: blockhash({}) -> {} self.env_info.number={}\n", number, r, self.env_info.number);
 				r
 			},
 			false => {
-				trace!("ext: blockhash({}) -> null self.info.number={}\n", number, self.info.number);
+				trace!("ext: blockhash({}) -> null self.env_info.number={}\n", number, self.env_info.number);
 				H256::from(&U256::zero())
 			},
 		}
@@ -83,26 +102,26 @@ impl<'a> Ext for Externalities<'a> {
 
 	fn create(&mut self, gas: &U256, value: &U256, code: &[u8]) -> ContractCreateResult {
 		// create new contract address
-		let address = contract_address(&self.params.address, &self.state.nonce(&self.params.address));
+		let address = contract_address(&self.origin_info.address, &self.state.nonce(&self.origin_info.address));
 
 		// prepare the params
 		let params = ActionParams {
 			code_address: address.clone(),
 			address: address.clone(),
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: Some(code.to_vec()),
 			data: None,
 		};
 
-		self.state.inc_nonce(&self.params.address);
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		self.state.inc_nonce(&self.origin_info.address);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 		
 		// TODO: handle internal error separately
-		match ex.create(&params, self.substate) {
+		match ex.create(params, self.substate) {
 			Ok(gas_left) => {
 				self.substate.contracts_created.push(address.clone());
 				ContractCreateResult::Created(address, gas_left)
@@ -122,18 +141,18 @@ impl<'a> Ext for Externalities<'a> {
 		let params = ActionParams {
 			code_address: code_address.clone(),
 			address: address.clone(), 
-			sender: self.params.address.clone(),
-			origin: self.params.origin.clone(),
+			sender: self.origin_info.address.clone(),
+			origin: self.origin_info.origin.clone(),
 			gas: *gas,
-			gas_price: self.params.gas_price.clone(),
+			gas_price: self.origin_info.gas_price.clone(),
 			value: value.clone(),
 			code: self.state.code(code_address),
 			data: Some(data.to_vec()),
 		};
 
-		let mut ex = Executive::from_parent(self.state, self.info, self.engine, self.depth);
+		let mut ex = Executive::from_parent(self.state, self.env_info, self.engine, self.depth);
 
-		match ex.call(&params, self.substate, BytesRef::Fixed(output)) {
+		match ex.call(params, self.substate, BytesRef::Fixed(output)) {
 			Ok(gas_left) => MessageCallResult::Success(gas_left),
 			_ => MessageCallResult::Failed
 		}
@@ -171,7 +190,7 @@ impl<'a> Ext for Externalities<'a> {
 					ptr::copy(data.as_ptr(), code.as_mut_ptr(), data.len());
 					code.set_len(data.len());
 				}
-				let address = &self.params.address;
+				let address = &self.origin_info.address;
 				self.state.init_code(address, code);
 				Ok(*gas - return_cost)
 			}
@@ -179,12 +198,12 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn log(&mut self, topics: Vec<H256>, data: Bytes) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		self.substate.logs.push(LogEntry::new(address, topics, data));
 	}
 
 	fn suicide(&mut self, refund_address: &Address) {
-		let address = self.params.address.clone();
+		let address = self.origin_info.address.clone();
 		let balance = self.balance(&address);
 		self.state.transfer_balance(&address, refund_address, &balance);
 		self.substate.suicides.insert(address);
@@ -195,14 +214,14 @@ impl<'a> Ext for Externalities<'a> {
 	}
 
 	fn env_info(&self) -> &EnvInfo {
-		&self.info
+		&self.env_info
 	}
 
 	fn depth(&self) -> usize {
 		self.depth
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.substate.sstore_refunds_count = self.substate.sstore_refunds_count + U256::one();
+	fn inc_sstore_refund(&mut self) {
+		self.substate.sstore_clears_count = self.substate.sstore_clears_count + U256::one();
 	}
 }
diff --git a/src/substate.rs b/src/substate.rs
index d3bbc12cc..9a1d6741e 100644
--- a/src/substate.rs
+++ b/src/substate.rs
@@ -9,7 +9,7 @@ pub struct Substate {
 	/// Any logs.
 	pub logs: Vec<LogEntry>,
 	/// Refund counter of SSTORE nonzero -> zero.
-	pub sstore_refunds_count: U256,
+	pub sstore_clears_count: U256,
 	/// Created contracts.
 	pub contracts_created: Vec<Address>
 }
@@ -20,7 +20,7 @@ impl Substate {
 		Substate {
 			suicides: HashSet::new(),
 			logs: vec![],
-			sstore_refunds_count: U256::zero(),
+			sstore_clears_count: U256::zero(),
 			contracts_created: vec![]
 		}
 	}
@@ -28,7 +28,7 @@ impl Substate {
 	pub fn accrue(&mut self, s: Substate) {
 		self.suicides.extend(s.suicides.into_iter());
 		self.logs.extend(s.logs.into_iter());
-		self.sstore_refunds_count = self.sstore_refunds_count + s.sstore_refunds_count;
+		self.sstore_clears_count = self.sstore_clears_count + s.sstore_clears_count;
 		self.contracts_created.extend(s.contracts_created.into_iter());
 	}
 }
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 4d0898676..7af8c91b5 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -36,7 +36,7 @@ impl Engine for TestEngine {
 struct CallCreate {
 	data: Bytes,
 	destination: Option<Address>,
-	_gas_limit: U256,
+	gas_limit: U256,
 	value: U256
 }
 
@@ -53,12 +53,13 @@ impl<'a> TestExt<'a> {
 			   info: &'a EnvInfo, 
 			   engine: &'a Engine, 
 			   depth: usize,
-			   params: &'a ActionParams, 
+			   origin_info: OriginInfo,
 			   substate: &'a mut Substate, 
-			   output: OutputPolicy<'a>) -> Self {
+			   output: OutputPolicy<'a>,
+			   address: Address) -> Self {
 		TestExt {
-			contract_address: contract_address(&params.address, &state.nonce(&params.address)),
-			ext: Externalities::new(state, info, engine, depth, params, substate, output),
+			contract_address: contract_address(&address, &state.nonce(&address)),
+			ext: Externalities::new(state, info, engine, depth, origin_info, substate, output),
 			callcreates: vec![]
 		}
 	}
@@ -89,7 +90,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: code.to_vec(),
 			destination: None,
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		ContractCreateResult::Created(self.contract_address.clone(), *gas)
@@ -105,7 +106,7 @@ impl<'a> Ext for TestExt<'a> {
 		self.callcreates.push(CallCreate {
 			data: data.to_vec(),
 			destination: Some(receive_address.clone()),
-			_gas_limit: *gas,
+			gas_limit: *gas,
 			value: *value
 		});
 		MessageCallResult::Success(*gas)
@@ -139,8 +140,8 @@ impl<'a> Ext for TestExt<'a> {
 		0
 	}
 
-	fn add_sstore_refund(&mut self) {
-		self.ext.add_sstore_refund()
+	fn inc_sstore_refund(&mut self) {
+		self.ext.inc_sstore_refund()
 	}
 }
 
@@ -205,9 +206,16 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 
 		// execute
 		let (res, callcreates) = {
-			let mut ex = TestExt::new(&mut state, &info, &engine, 0, &params, &mut substate, OutputPolicy::Return(BytesRef::Flexible(&mut output)));
+			let mut ex = TestExt::new(&mut state, 
+									  &info, 
+									  &engine, 
+									  0, 
+									  OriginInfo::from(&params), 
+									  &mut substate, 
+									  OutputPolicy::Return(BytesRef::Flexible(&mut output)),
+									  params.address.clone());
 			let evm = Factory::create();
-			let res = evm.exec(&params, &mut ex);
+			let res = evm.exec(params, &mut ex);
 			(res, ex.callcreates)
 		};
 
@@ -237,11 +245,7 @@ fn do_json_test(json_data: &[u8]) -> Vec<String> {
 					fail_unless(callcreate.data == Bytes::from_json(&expected["data"]), "callcreates data is incorrect");
 					fail_unless(callcreate.destination == xjson!(&expected["destination"]), "callcreates destination is incorrect");
 					fail_unless(callcreate.value == xjson!(&expected["value"]), "callcreates value is incorrect");
-
-					// TODO: call_gas is calculated in externalities and is not exposed to TestExt.
-					// maybe move it to it's own function to simplify calculation?
-					//println!("name: {:?}, callcreate {:?}, expected: {:?}", name, callcreate.gas_limit, U256::from(&expected["gasLimit"]));
-					//fail_unless(callcreate.gas_limit == U256::from(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
+					fail_unless(callcreate.gas_limit == xjson!(&expected["gasLimit"]), "callcreates gas_limit is incorrect");
 				}
 			}
 		}
