commit f5af1fdca8dc7d44b4c2025195c19819886729b6
Author: obscuren <geffobscura@gmail.com>
Date:   Tue May 19 17:26:38 2015 +0200

    core/vm: RETURN op code returns pointer to memory rather than copy

diff --git a/core/vm/memory.go b/core/vm/memory.go
index b77d486eb..d20aa9591 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -49,6 +49,18 @@ func (self *Memory) Get(offset, size int64) (cpy []byte) {
 	return
 }
 
+func (self *Memory) GetPtr(offset, size int64) []byte {
+	if size == 0 {
+		return nil
+	}
+
+	if len(self.store) > int(offset) {
+		return self.store[offset : offset+size]
+	}
+
+	return nil
+}
+
 func (m *Memory) Len() int {
 	return len(m.store)
 }
diff --git a/core/vm/vm.go b/core/vm/vm.go
index 927b67293..35fa19d03 100644
--- a/core/vm/vm.go
+++ b/core/vm/vm.go
@@ -695,7 +695,7 @@ func (self *Vm) Run(context *Context, callData []byte) (ret []byte, err error) {
 			self.Printf("resume %x (%v)", context.Address(), context.Gas)
 		case RETURN:
 			offset, size := stack.pop(), stack.pop()
-			ret := mem.Get(offset.Int64(), size.Int64())
+			ret := mem.GetPtr(offset.Int64(), size.Int64())
 
 			self.Printf(" => [%v, %v] (%d) 0x%x", offset, size, len(ret), ret).Endl()
 
diff --git a/tests/vm/gh_test.go b/tests/vm/gh_test.go
index b01448420..827d8ec8b 100644
--- a/tests/vm/gh_test.go
+++ b/tests/vm/gh_test.go
@@ -286,13 +286,13 @@ func TestInputLimitsLight(t *testing.T) {
 	RunVmTest(fn, t)
 }
 
-func TestStateExample(t *testing.T) {
-	const fn = "../files/StateTests/stExample.json"
+func TestStateSystemOperations(t *testing.T) {
+	const fn = "../files/StateTests/stSystemOperationsTest.json"
 	RunVmTest(fn, t)
 }
 
-func TestStateSystemOperations(t *testing.T) {
-	const fn = "../files/StateTests/stSystemOperationsTest.json"
+func TestStateExample(t *testing.T) {
+	const fn = "../files/StateTests/stExample.json"
 	RunVmTest(fn, t)
 }
 
