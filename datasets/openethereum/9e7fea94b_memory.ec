commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
commit 9e7fea94bfe2ea36f21030095d30a391462a07e9
Author: Tomusdrw <tomusdrw@gmail.com>
Date:   Fri Jan 15 23:32:16 2016 +0100

    Fixing memory allocation

diff --git a/src/evm/interpreter.rs b/src/evm/interpreter.rs
index f60bf868c..49231ed8f 100644
--- a/src/evm/interpreter.rs
+++ b/src/evm/interpreter.rs
@@ -45,7 +45,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 		let val = self.pop();
 		match val {
 			Some(x) => {
-				// println!("Poping from stack: {}", x);
+				println!("Poping from stack: {}", x);
 				x
 			},
 			None => panic!("Tried to pop from empty stack.")
@@ -62,7 +62,7 @@ impl<S : fmt::Display> Stack<S> for Vec<S> {
 	}
 
 	fn push(&mut self, elem: S) {
-		// println!("Pushing to stack: {}", elem);
+		println!("Pushing to stack: {}", elem);
 		self.push(elem);
 	}
 
@@ -216,14 +216,17 @@ impl evm::Evm for Interpreter {
 			reader.position += 1;
 
 			// Calculate gas cost
-			let gas_cost = try!(self.get_gas_cost_and_expand_mem(ext, instruction, &mut mem, &stack));
+			let (gas_cost, mem_size) = try!(self.get_gas_cost_mem(ext, instruction, &mut mem, &stack));
 			try!(self.verify_gas(&current_gas, &gas_cost));
+			mem.expand(mem_size);
 			current_gas = current_gas - gas_cost;
-			// println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
-			// 				   instructions::get_info(instruction).name, instruction,
-			// 				   gas_cost,
-			// 				   current_gas
-			// );
+
+			println!("Executing: {} (0x{:x}) [Gas Cost: {} (Left: {})]", 
+							   instructions::get_info(instruction).name, instruction,
+							   gas_cost,
+							   current_gas
+			);
+
 			// Execute instruction
 			let result = try!(self.exec_instruction(
 					current_gas, params, ext, instruction, &mut reader, &mut mem, &mut stack
@@ -254,12 +257,12 @@ impl evm::Evm for Interpreter {
 
 impl Interpreter {
 
-	fn get_gas_cost_and_expand_mem(&self,
-								   ext: &evm::Ext,
-								   instruction: Instruction,
-								   mem: &mut Memory,
-								   stack: &Stack<U256>
-								  ) -> evm::Result {
+	fn get_gas_cost_mem(&self,
+						ext: &evm::Ext,
+						instruction: Instruction,
+						mem: &mut Memory,
+						stack: &Stack<U256>
+					   ) -> Result<(U256, usize), evm::Error> {
 		let schedule = ext.schedule();
 		let info = instructions::get_info(instruction);
 
@@ -367,14 +370,13 @@ impl Interpreter {
 
 		match cost {
 			InstructionCost::Gas(gas) => {
-				Ok(gas)
+				Ok((gas, 0))
 			},
 			InstructionCost::GasMem(gas, mem_size) => match mem_size {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(gas, mem_gas)
+					let gas = try!(self.gas_add(gas, mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			},
@@ -382,9 +384,8 @@ impl Interpreter {
 				RequiredMem::Mem(mem_size) => {
 					let (mem_gas, new_mem_size) = self.mem_gas_cost(schedule, mem.size(), &mem_size);
 					let copy_gas = U256::from(schedule.copy_gas) * (add_u256_usize(&copy, 31) / U256::from(32));
-					// Expand after calculating the cost
-					mem.expand(new_mem_size);
-					self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas)
+					let gas = try!(self.gas_add(try!(self.gas_add(gas, copy_gas)), mem_gas));
+					Ok((gas, new_mem_size))
 				},
 				RequiredMem::OutOfMemory => Err(evm::Error::OutOfGas)
 			}
diff --git a/src/executive.rs b/src/executive.rs
index 90a0d24ca..6baf67707 100644
--- a/src/executive.rs
+++ b/src/executive.rs
@@ -763,4 +763,40 @@ mod tests {
 			_ => assert!(false, "Expected not enough cash error. {:?}", res)
 		}
 	}
+
+	evm_test!{test_sha3: test_sha3_jit, test_sha3_int}
+	fn test_sha3(factory: Factory) {
+		let code = "6064640fffffffff20600055".from_hex().unwrap();
+
+		let sender = Address::from_str("0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6").unwrap();
+		let address = contract_address(&sender, &U256::zero());
+		// TODO: add tests for 'callcreate'
+		//let next_address = contract_address(&address, &U256::zero());
+		let mut params = ActionParams::new();
+		params.address = address.clone();
+		params.sender = sender.clone();
+		params.origin = sender.clone();
+		params.gas = U256::from(0x0186a0);
+		params.code = code.clone();
+		params.value = U256::from_str("0de0b6b3a7640000").unwrap();
+		let mut state = State::new_temp();
+		state.add_balance(&sender, &U256::from_str("152d02c7e14af6800000").unwrap());
+		let info = EnvInfo::new();
+		let engine = TestEngine::new(0, factory);
+		let mut substate = Substate::new();
+
+		let result = {
+			let mut ex = Executive::new(&mut state, &info, &engine);
+			ex.create(&params, &mut substate)
+		};
+
+		match result {
+			Err(_) => {
+			},
+			_ => {
+				panic!("Expected OutOfGas");
+			}
+		}
+	}
+
 }
