commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
commit 92fd00f41e0f6a2abaac55577f5fe2834eee566e
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Tue Jul 12 09:49:16 2016 +0200

    EVM gas for memory tiny optimization (#1578)
    
    * EVM bin benches
    
    * Optimizing mem gas cost
    
    * Removing overflow_div since it's not used
    
    * More benchmarks

diff --git a/ethcore/src/evm/evm.rs b/ethcore/src/evm/evm.rs
index 3ec943f18..77b57bf69 100644
--- a/ethcore/src/evm/evm.rs
+++ b/ethcore/src/evm/evm.rs
@@ -107,6 +107,9 @@ pub trait CostType: ops::Mul<Output=Self> + ops::Div<Output=Self> + ops::Add<Out
 	fn overflow_add(self, other: Self) -> (Self, bool);
 	/// Multiple with overflow
 	fn overflow_mul(self, other: Self) -> (Self, bool);
+	/// Single-step full multiplication and division: `self*other/div`
+	/// Should not overflow on intermediate steps
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool);
 }
 
 impl CostType for U256 {
@@ -129,6 +132,17 @@ impl CostType for U256 {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		Uint::overflowing_mul(self, other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let x = self.full_mul(other);
+		let (U512(parts), o) = Uint::overflowing_div(x, U512::from(div));
+		let overflow = (parts[4] | parts[5] | parts[6] | parts[7]) > 0;
+
+		(
+			U256([parts[0], parts[1], parts[2], parts[3]]),
+			o | overflow
+		)
+	}
 }
 
 impl CostType for usize {
@@ -154,6 +168,14 @@ impl CostType for usize {
 	fn overflow_mul(self, other: Self) -> (Self, bool) {
 		self.overflowing_mul(other)
 	}
+
+	fn overflow_mul_div(self, other: Self, div: Self) -> (Self, bool) {
+		let (c, o) = U128::from(self).overflowing_mul(U128::from(other));
+		let (U128(parts), o1) = c.overflowing_div(U128::from(div));
+		let result = parts[0] as usize;
+		let overflow = o | o1 | (parts[1] > 0) | (parts[0] > result as u64);
+		(result, overflow)
+	}
 }
 
 /// Evm interface
@@ -164,3 +186,41 @@ pub trait Evm {
 	/// to compute the final gas left.
 	fn exec(&mut self, params: ActionParams, ext: &mut Ext) -> Result<GasLeft>;
 }
+
+
+#[test]
+fn should_calculate_overflow_mul_div_without_overflow() {
+	// given
+	let num = 10_000_000;
+
+	// when
+	let (res1, o1) = U256::from(num).overflow_mul_div(U256::from(num), U256::from(num));
+	let (res2, o2) = num.overflow_mul_div(num, num);
+
+	// then
+	assert_eq!(res1, U256::from(num));
+	assert!(!o1);
+	assert_eq!(res2, num);
+	assert!(!o2);
+}
+
+#[test]
+fn should_calculate_overflow_mul_div_with_overflow() {
+	// given
+	let max = ::std::u64::MAX;
+	let num1 = U256([max, max, max, max]);
+	let num2 = ::std::usize::MAX;
+
+	// when
+	let (res1, o1) = num1.overflow_mul_div(num1, num1 - U256::from(2));
+	let (res2, o2) = num2.overflow_mul_div(num2, num2 - 2);
+
+	// then
+	// (x+2)^2/x = (x^2 + 4x + 4)/x = x + 4 + 4/x ~ (MAX-2) + 4 + 0 = 1
+	assert_eq!(res2, 1);
+	assert!(o2);
+
+	assert_eq!(res1, U256::from(1));
+	assert!(o1);
+}
+
diff --git a/ethcore/src/evm/interpreter/gasometer.rs b/ethcore/src/evm/interpreter/gasometer.rs
index 069d70e19..0fc349a27 100644
--- a/ethcore/src/evm/interpreter/gasometer.rs
+++ b/ethcore/src/evm/interpreter/gasometer.rs
@@ -68,6 +68,9 @@ impl<Gas: CostType> Gasometer<Gas> {
 		let default_gas = Gas::from(schedule.tier_step_gas[tier]);
 
 		let cost = match instruction {
+			instructions::JUMPDEST => {
+				InstructionCost::Gas(Gas::from(1))
+			},
 			instructions::SSTORE => {
 				let address = H256::from(stack.peek(0));
 				let newval = stack.peek(1);
@@ -106,9 +109,6 @@ impl<Gas: CostType> Gasometer<Gas> {
 			instructions::EXTCODECOPY => {
 				InstructionCost::GasMemCopy(default_gas, try!(self.mem_needed(stack.peek(1), stack.peek(3))), try!(Gas::from_u256(*stack.peek(3))))
 			},
-			instructions::JUMPDEST => {
-				InstructionCost::Gas(Gas::from(1))
-			},
 			instructions::LOG0...instructions::LOG4 => {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
@@ -199,14 +199,12 @@ impl<Gas: CostType> Gasometer<Gas> {
 			let s = mem_size >> 5;
 			// s * memory_gas + s * s / quad_coeff_div
 			let a = overflowing!(s.overflow_mul(Gas::from(schedule.memory_gas)));
-			// We need to go to U512 to calculate s*s/quad_coeff_div
-			let b = U512::from(s.as_u256()) * U512::from(s.as_u256()) / U512::from(schedule.quad_coeff_div);
-			if b > U512::from(!U256::zero()) {
-				Err(evm::Error::OutOfGas)
-			} else {
-				Ok(overflowing!(a.overflow_add(try!(Gas::from_u256(U256::from(b))))))
-			}
+
+			// Calculate s*s/quad_coeff_div
+			let b = overflowing!(s.overflow_mul_div(s, Gas::from(schedule.quad_coeff_div)));
+			Ok(overflowing!(a.overflow_add(b)))
 		};
+
 		let current_mem_size = Gas::from(current_mem_size);
 		let req_mem_size_rounded = (overflowing!(mem_size.overflow_add(Gas::from(31 as usize))) >> 5) << 5;
 
diff --git a/evmbin/Cargo.toml b/evmbin/Cargo.toml
index 3e531f5d3..8ec687687 100644
--- a/evmbin/Cargo.toml
+++ b/evmbin/Cargo.toml
@@ -4,6 +4,14 @@ description = "Parity's EVM implementation"
 version = "0.1.0"
 authors = ["Ethcore <admin@ethcore.io>"]
 
+[lib]
+name = "evm"
+path = "./src/main.rs"
+
+[[bin]]
+name = "evm"
+path = "./src/main.rs"
+
 [dependencies]
 rustc-serialize = "0.3"
 docopt = { version = "0.6" }
diff --git a/evmbin/bench.sh b/evmbin/bench.sh
new file mode 100755
index 000000000..a7d5557cb
--- /dev/null
+++ b/evmbin/bench.sh
@@ -0,0 +1,24 @@
+#!/bin/bash
+
+set -x
+set -e
+
+cargo build --release
+
+# LOOP TEST
+CODE1=606060405260005b620f42408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200
+ethvm --code $CODE1
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE1 --gas 4402000
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE1
+echo "^^^^ U256"
+
+# RNG TEST
+CODE2=6060604052600360056007600b60005b620f4240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200
+ethvm --code $CODE2
+echo "^^^^ ethvm"
+./target/release/evm stats --code $CODE2 --gas 143020115
+echo "^^^^ usize"
+./target/release/evm stats --code $CODE2
+echo "^^^^ U256"
diff --git a/evmbin/benches/mod.rs b/evmbin/benches/mod.rs
new file mode 100644
index 000000000..3013dca54
--- /dev/null
+++ b/evmbin/benches/mod.rs
@@ -0,0 +1,85 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! benchmarking for EVM
+//! should be started with:
+//! ```bash
+//! multirust run nightly cargo bench
+//! ```
+
+#![feature(test)]
+
+extern crate test;
+extern crate ethcore;
+extern crate evm;
+extern crate ethcore_util;
+extern crate rustc_serialize;
+
+use self::test::{Bencher, black_box};
+
+use evm::run_vm;
+use ethcore::action_params::ActionParams;
+use ethcore_util::{U256, Uint};
+use rustc_serialize::hex::FromHex;
+
+#[bench]
+fn simple_loop_usize(b: &mut Bencher) {
+	simple_loop(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn simple_loop_u256(b: &mut Bencher) {
+	simple_loop(!U256::zero(), b)
+}
+
+fn simple_loop(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"606060405260005b620042408112156019575b6001016007565b600081905550600680602b6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
+#[bench]
+fn rng_usize(b: &mut Bencher) {
+	rng(U256::from(::std::usize::MAX), b)
+}
+
+#[bench]
+fn rng_u256(b: &mut Bencher) {
+	rng(!U256::zero(), b)
+}
+
+fn rng(gas: U256, b: &mut Bencher) {
+	let code = black_box(
+		"6060604052600360056007600b60005b62004240811215607f5767ffe7649d5eca84179490940267f47ed85c4b9a6379019367f8e5dd9a5c994bba9390930267f91d87e4b8b74e55019267ff97f6f3b29cda529290920267f393ada8dd75c938019167fe8d437c45bb3735830267f47d9a7b5428ffec019150600101600f565b838518831882186000555050505050600680609a6000396000f3606060405200".from_hex().unwrap()
+	);
+
+	b.iter(|| {
+		let mut params = ActionParams::default();
+		params.gas = gas;
+		params.code = Some(code.clone());
+
+		run_vm(params)
+	});
+}
+
diff --git a/evmbin/src/main.rs b/evmbin/src/main.rs
index 3fa06d004..94684129c 100644
--- a/evmbin/src/main.rs
+++ b/evmbin/src/main.rs
@@ -17,6 +17,7 @@
 //! Parity EVM interpreter binary.
 
 #![warn(missing_docs)]
+#![allow(dead_code)]
 extern crate ethcore;
 extern crate rustc_serialize;
 extern crate docopt;
@@ -25,7 +26,7 @@ extern crate ethcore_util as util;
 
 mod ext;
 
-use std::time::Instant;
+use std::time::{Instant, Duration};
 use std::str::FromStr;
 use docopt::Docopt;
 use util::{U256, FromHex, Uint, Bytes};
@@ -58,6 +59,15 @@ fn main() {
 	params.code = Some(args.code());
 	params.data = args.data();
 
+	let result = run_vm(params);
+	println!("Gas used: {:?}", result.gas_used);
+	println!("Output: {:?}", result.output);
+	println!("Time: {}.{:.9}s", result.time.as_secs(), result.time.subsec_nanos());
+}
+
+/// Execute VM with given `ActionParams`
+pub fn run_vm(params: ActionParams) -> ExecutionResults {
+	let initial_gas = params.gas;
 	let factory = Factory::new(VMType::Interpreter);
 	let mut vm = factory.create(params.gas);
 	let mut ext = ext::FakeExt::default();
@@ -66,9 +76,21 @@ fn main() {
 	let gas_left = vm.exec(params, &mut ext).finalize(ext).expect("OK");
 	let duration = start.elapsed();
 
-	println!("Gas used: {:?}", args.gas() - gas_left);
-	println!("Output: {:?}", "");
-	println!("Time: {}.{:.9}s", duration.as_secs(), duration.subsec_nanos());
+	ExecutionResults {
+		gas_used: initial_gas - gas_left,
+		output: Vec::new(),
+		time: duration,
+	}
+}
+
+/// VM execution results
+pub struct ExecutionResults {
+	/// Used gas
+	pub gas_used: U256,
+	/// Output as bytes
+	pub output: Vec<u8>,
+	/// Time Taken
+	pub time: Duration,
 }
 
 #[derive(Debug, RustcDecodable)]
