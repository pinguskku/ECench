commit 24777cc569c66cf57c90cad26cc04dbc37bd2b3f
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Sat Jan 16 01:24:37 2016 +0100

    Fixing memory calculations overflows

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index 5925af6b6..99194a3f9 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -92,6 +92,13 @@ trait Memory {
 	fn writeable_slice(&mut self, offset: U256, size: U256) -> &mut[u8];
 	fn dump(&self);
 }
+
+fn is_valid_range(off: usize, size: usize)  -> bool {
+	// When size is zero we haven't actually expanded the memory
+	let (_a, overflow) = off.overflowing_add(size);
+	size > 0 && !overflow
+}
+
 impl Memory for Vec<u8> {
 	fn dump(&self) {
 		println!("MemoryDump:");
@@ -106,13 +113,12 @@ impl Memory for Vec<u8> {
 	}
 
 	fn read_slice(&self, init_off_u: U256, init_size_u: U256) -> &[u8] {
-		let init_off = init_off_u.low_u64() as usize;
-		let init_size = init_size_u.low_u64() as usize;
-		// When size is zero we haven't actually expanded the memory
-		if init_size == 0 {
+		let off = init_off_u.low_u64() as usize;
+		let size = init_size_u.low_u64() as usize;
+		if !is_valid_range(off, size) {
 			&self[0..0]
 		} else {
-			&self[init_off..init_off + init_size]
+			&self[off..off+size]
 		}
 	}
 
@@ -124,8 +130,7 @@ impl Memory for Vec<u8> {
 	fn writeable_slice(&mut self, offset: U256, size: U256) -> &mut [u8] {
 		let off = offset.low_u64() as usize;
 		let s = size.low_u64() as usize;
-
-		if s == 0 {
+		if !is_valid_range(off, s) {
 			&mut self[0..0]
 		} else {
 			&mut self[off..off+s]
@@ -323,9 +328,14 @@ impl Interpreter {
 				InstructionCost::GasMem(default_gas, self.mem_needed(stack.peek(0), stack.peek(1)))
 			},
 			instructions::SHA3 => {
-				let words = add_u256_usize(stack.peek(1), 31) >> 5;
-				let gas = U256::from(schedule.sha3_gas) + (U256::from(schedule.sha3_word_gas) * words);
-				InstructionCost::GasMem(gas, self.mem_needed(stack.peek(0), stack.peek(1)))
+				match add_u256_usize(stack.peek(1), 31) {
+					(_w, true) => InstructionCost::GasMem(U256::zero(), RequiredMem::OutOfMemory),
+					(w, false) => {
+						let words = w >> 5;
+						let gas = U256::from(schedule.sha3_gas) + (U256::from(schedule.sha3_word_gas) * words);
+						InstructionCost::GasMem(gas, self.mem_needed(stack.peek(0), stack.peek(1)))
+					}
+				}
 			},
 			instructions::CALLDATACOPY => {
 				InstructionCost::GasMemCopy(default_gas, self.mem_needed(stack.peek(0), stack.peek(2)), stack.peek(2).clone())
@@ -356,13 +366,16 @@ impl Interpreter {
 				InstructionCost::GasMem(gas, mem)
 			},
 			instructions::DELEGATECALL => {
-				let gas = add_u256_usize(stack.peek(0), schedule.call_gas);
-
-				let mem = self.mem_max(
-					self.mem_needed(stack.peek(4), stack.peek(5)),
-					self.mem_needed(stack.peek(2), stack.peek(3))
-				);
-				InstructionCost::GasMem(gas, mem)
+				match add_u256_usize(stack.peek(0), schedule.call_gas) {
+					(_gas, true) => InstructionCost::GasMem(U256::zero(), RequiredMem::OutOfMemory),
+					(gas, false) => {
+						let mem = self.mem_max(
+							self.mem_needed(stack.peek(4), stack.peek(5)),
+							self.mem_needed(stack.peek(2), stack.peek(3))
+						);
+						InstructionCost::GasMem(gas, mem)
+					}
+				}
 			},
 			instructions::CREATE => {
 				let gas = U256::from(schedule.create_gas);
@@ -393,9 +406,14 @@ impl Interpreter {
 			InstructionCost::GasMemCopy(gas, mem_size, copy) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
-					Ok((gas, new_mem_size))
+					match add_u256_usize(&copy, 31) {
+						(_c, true) => Err(evm::Error::OutOfGas),
+						(copy, false) => {
+							let copy_gas = U256::from(schedule.copy_gas) * (copy / U256::from(32));
+							let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+							Ok((gas, new_mem_size))
+						}
+					}
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
@@ -415,16 +433,16 @@ impl Interpreter {
 			s * U256::from(schedule.memory_gas) + s * s / U256::from(schedule.quad_coeff_div)
 		};
 
-		let req_mem_size = mem_size.low_u64() as usize;
-		let req_mem_size_rounded = (req_mem_size + 31) / 32 * 32;
+		let current_mem_size = U256::from(current_mem_size);
+		let req_mem_size_rounded = ((mem_size.clone() + U256::from(31)) >> 5) << 5;
 		let new_mem_gas = gas_for_mem(U256::from(req_mem_size_rounded));
-		let current_mem_gas = gas_for_mem(U256::from(current_mem_size));
+		let current_mem_gas = gas_for_mem(current_mem_size);
 
 		(if req_mem_size_rounded > current_mem_size {
 			new_mem_gas - current_mem_gas
 		} else {
 			U256::zero()
-		}, req_mem_size_rounded)
+		}, req_mem_size_rounded.low_u64() as usize)
 	}
 
 
@@ -452,7 +470,9 @@ impl Interpreter {
 		} else {
 			match offset.clone().overflowing_add(size.clone()) {
 				(_result, true) => RequiredMem::OutOfMemory,
-				(result, false) => RequiredMem::Mem(result)
+				(result, false) => {
+						RequiredMem::Mem(result)
+				}
 			}
 		}
 	}
@@ -1009,8 +1029,8 @@ pub fn set_sign(value: U256, sign: bool) -> U256 {
 	}
 }
 
-fn add_u256_usize(value: &U256, num: usize) -> U256 {
-	value.clone() + U256::from(num)
+fn add_u256_usize(value: &U256, num: usize) -> (U256, bool) {
+	value.clone().overflowing_add(U256::from(num))
 }
 
 fn u256_to_address(value: &U256) -> Address {
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 9d5d23ad7..39a08da24 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -168,9 +168,6 @@ fn do_json_test_for(vm: &VMType, json_data: &[u8]) -> Vec<String> {
 	let json = Json::from_str(::std::str::from_utf8(json_data).unwrap()).expect("Json is invalid");
 	let mut failed = Vec::new();
 	for (name, test) in json.as_object().unwrap() {
-		// if name != "CallToNameRegistrator0" {
-			// continue;
-		// }
 		println!("name: {:?}", name);
 		// sync io is usefull when something crashes in jit
 		// ::std::io::stdout().write(&name.as_bytes());
