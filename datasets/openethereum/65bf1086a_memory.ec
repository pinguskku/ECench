commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
commit 65bf1086a2edc9339ab988a22754c9fea54e59a8
Author: cheme <emericchevalier.pro@gmail.com>
Date:   Tue Sep 11 17:47:26 2018 +0200

    In create memory calculation is the same for create2 because the additional parameter was popped before. (#9522)

diff --git a/ethcore/evm/src/interpreter/gasometer.rs b/ethcore/evm/src/interpreter/gasometer.rs
index 406df19fd..db67556e3 100644
--- a/ethcore/evm/src/interpreter/gasometer.rs
+++ b/ethcore/evm/src/interpreter/gasometer.rs
@@ -233,11 +233,7 @@ impl<Gas: evm::CostType> Gasometer<Gas> {
 			},
 			instructions::CREATE | instructions::CREATE2 => {
 				let gas = Gas::from(schedule.create_gas);
-				let mem = match instruction {
-					instructions::CREATE => mem_needed(stack.peek(1), stack.peek(2))?,
-					instructions::CREATE2 => mem_needed(stack.peek(2), stack.peek(3))?,
-					_ => unreachable!("instruction can only be CREATE/CREATE2 checked above; qed"),
-				};
+				let mem = mem_needed(stack.peek(1), stack.peek(2))?;
 
 				Request::GasMemProvide(gas, mem, None)
 			},
