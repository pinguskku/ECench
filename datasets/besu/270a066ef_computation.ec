commit 270a066ef1c00e14a28be007d776933d35b47533
Author: matkt <karim.t2am@gmail.com>
Date:   Mon Nov 15 10:01:00 2021 +0100

    improve perf trace (#3032)
    
    Signed-off-by: Karim TAAM <karim.t2am@gmail.com>

diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/debug/TraceFrame.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/debug/TraceFrame.java
index 31143f907..53b77068b 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/debug/TraceFrame.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/debug/TraceFrame.java
@@ -93,7 +93,7 @@ public class TraceFrame {
     this.exceptionalHaltReason = exceptionalHaltReason;
     this.recipient = recipient;
     this.value = value;
-    this.inputData = inputData.copy();
+    this.inputData = inputData;
     this.outputData = outputData;
     this.stack = stack;
     this.memory = memory;
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/DebugOperationTracer.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/DebugOperationTracer.java
index 12a64dc77..470ccec3b 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/DebugOperationTracer.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/DebugOperationTracer.java
@@ -80,7 +80,7 @@ public class DebugOperationTracer implements OperationTracer {
             operationResult.getHaltReason(),
             frame.getRecipientAddress(),
             frame.getApparentValue(),
-            inputData,
+            pc == 0 ? inputData.copy() : inputData,
             outputData,
             stack,
             memory,
@@ -113,7 +113,7 @@ public class DebugOperationTracer implements OperationTracer {
               Optional.empty(),
               frame.getRecipientAddress(),
               frame.getValue(),
-              frame.getInputData(),
+              frame.getInputData().copy(),
               frame.getOutputData(),
               Optional.empty(),
               Optional.empty(),
@@ -159,7 +159,7 @@ public class DebugOperationTracer implements OperationTracer {
                     Optional.of(exceptionalHaltReason),
                     frame.getRecipientAddress(),
                     frame.getValue(),
-                    frame.getInputData(),
+                    frame.getInputData().copy(),
                     frame.getOutputData(),
                     Optional.empty(),
                     Optional.empty(),