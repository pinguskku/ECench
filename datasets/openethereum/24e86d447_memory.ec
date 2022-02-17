commit 24e86d44797a982846c095c9d005688a905c19df
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 21:46:08 2016 +0100

    Fixing possible gas-memory calculation overflows

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index ac2f092e6..63c4e5869 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -165,11 +165,17 @@ impl<'a> CodeReader<'a> {
 	}
 }
 
+enum RequiredMem {
+	Mem(U256),
+	OutOfMemory
+}
+
 enum InstructionCost {
 	Gas(U256),
-	GasMem(U256, U256),
-	GasMemCopy(U256, U256, U256)
+	GasMem(U256, RequiredMem),
+	GasMemCopy(U256, RequiredMem, U256)
 }
+
 enum InstructionResult {
 	AdditionalGasCost(U256),
 	JumpToPosition(U256),
@@ -279,13 +285,13 @@ impl Interpreter {
 				InstructionCost::Gas(U256::from(schedule.sload_gas))
 			},
 			instructions::MSTORE => {
-				InstructionCost::GasMem(default_gas, add_u256_usize(stack.peek(0), 32))
+				InstructionCost::GasMem(default_gas, self.mem_needed_const(stack.peek(0), 32))
 			},
 			instructions::MLOAD => {
-				InstructionCost::GasMem(default_gas, add_u256_usize(stack.peek(0), 32))
+				InstructionCost::GasMem(default_gas, self.mem_needed_const(stack.peek(0), 32))
 			},
 			instructions::MSTORE8 => {
-				InstructionCost::GasMem(default_gas, add_u256_usize(stack.peek(0), 1))
+				InstructionCost::GasMem(default_gas, self.mem_needed_const(stack.peek(0), 1))
 			},
 			instructions::RETURN => {
 				InstructionCost::GasMem(default_gas, self.mem_needed(stack.peek(0), stack.peek(1)))
@@ -311,13 +317,13 @@ impl Interpreter {
 				let no_of_topics = instructions::get_log_topics(instruction);
 				let log_gas = schedule.log_gas + schedule.log_topic_gas * no_of_topics;
 				let data_gas = stack.peek(1).clone() * U256::from(schedule.log_data_gas);
-				let gas = data_gas + U256::from(log_gas);
+				let gas = try!(self.gas_add(data_gas, U256::from(log_gas)));
 				InstructionCost::GasMem(gas, self.mem_needed(stack.peek(0), stack.peek(1)))
 			},
 			instructions::CALL | instructions::CALLCODE => {
 				// [todr] we actuall call gas_cost is calculated in ext
 				let gas = U256::from(schedule.call_gas);
-				let mem = cmp::max(
+				let mem = self.mem_max(
 					self.mem_needed(stack.peek(5), stack.peek(6)),
 					self.mem_needed(stack.peek(3), stack.peek(4))
 				);
@@ -325,7 +331,8 @@ impl Interpreter {
 			},
 			instructions::DELEGATECALL => {
 				let gas = add_u256_usize(stack.peek(0), schedule.call_gas);
-				let mem = cmp::max(
+
+				let mem = self.mem_max(
 					self.mem_needed(stack.peek(4), stack.peek(5)),
 					self.mem_needed(stack.peek(2), stack.peek(3))
 				);
@@ -349,21 +356,34 @@ impl Interpreter {
 			InstructionCost::Gas(gas) => {
 				Ok(gas)
 			},
-			InstructionCost::GasMem(gas, mem_size) => {
-				let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-				// Expand after calculating the cost
-				mem.expand(new_mem_size);
-				Ok(gas + mem_gas)
-			},
-			InstructionCost::GasMemCopy(gas, mem_size, copy) => {
-				let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-				let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-				// Expand after calculating the cost
-				mem.expand(new_mem_size);
-				Ok(gas + copy_gas + mem_gas)
+			InstructionCost::GasMem(gas, mem_size) => match mem_size {
+				RequiredMem::Mem(mem_size) => {
+					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
+					// Expand after calculating the cost
+					mem.expand(new_mem_size);
+					self.gas_add(gas, mem_gas)
+				},
+				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
+			},
+			InstructionCost::GasMemCopy(gas, mem_size, copy) => match mem_size {
+				RequiredMem::Mem(mem_size) => {
+					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
+					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
+					// Expand after calculating the cost
+					mem.expand(new_mem_size);
+					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+				},
+				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
 		}
 	}
+
+	fn gas_add(&self, a: U256, b: U256) -> Result<U256, evm::Error> {
+		match a.overflowing_add(b) {
+			(_val, true) => Err(evm::Error::OutOfGas),
+			(val, false) => Ok(val)
+		}
+	}
 	
 	fn mem_gas_cost(&self, schedule: &evm::Schedule, current_mem_size: usize, mem_size: &U256) -> (U256, usize) {
 		let gas_for_mem = |mem_size: usize| {
@@ -384,11 +404,34 @@ impl Interpreter {
 	}
 
 
-	fn mem_needed(&self, offset: &U256, size: &U256) -> U256 {
+	fn mem_max(&self, m_a: RequiredMem, m_b: RequiredMem) -> RequiredMem {
+		match (m_a, m_b) {
+			(RequiredMem::Mem(a), RequiredMem::Mem(b)) => {
+				RequiredMem::Mem(cmp::max(a, b))
+			},
+			(RequiredMem::OutOfMemory, _) | (_, RequiredMem::OutOfMemory) => {
+				RequiredMem::OutOfMemory
+			}
+		}
+	}
+
+	fn mem_needed_const(&self, mem: &U256, add: usize) -> RequiredMem {
+		match mem.overflowing_add(U256::from(add)) {
+			(_, true) => RequiredMem::OutOfMemory,
+			(mem, false) => RequiredMem::Mem(mem)
+		}
+	}
+
+	fn mem_needed(&self, offset: &U256, size: &U256) -> RequiredMem {
 		if self.is_zero(size) {
-			U256::zero()
+			RequiredMem::Mem(U256::zero())
 		} else {
-			offset.clone() + size.clone()
+			let (result, overflow) = offset.clone().overflowing_add(size.clone());
+			if overflow {
+				RequiredMem::OutOfMemory
+			} else {
+				RequiredMem::Mem(result)
+			}
 		}
 	}
 
diff --git a/src/tests/executive.rs b/src/tests/executive.rs
index 68cc65c10..3f6395804 100644
--- a/src/tests/executive.rs
+++ b/src/tests/executive.rs
@@ -242,7 +242,7 @@ fn do_json_test_for(vm: &VMType, json_data: &[u8]) -> Vec<String> {
 		match res {
 			Err(_) => fail_unless(out_of_gas, "didn't expect to run out of gas."),
 			Ok(gas_left) => {
-				//println!("name: {}, gas_left : {:?}, expected: {:?}", name, gas_left, U256::from(&test["gas"]));
+				println!("name: {}, gas_left : {:?}", name, gas_left);
 				fail_unless(!out_of_gas, "expected to run out of gas.");
 				fail_unless(gas_left == xjson!(&test["gas"]), "gas_left is incorrect");
 				fail_unless(output == Bytes::from_json(&test["out"]), "output is incorrect");
