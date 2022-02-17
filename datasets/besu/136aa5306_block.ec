commit 136aa5306ead90798e2365077f1d11a92a385163
Author: Ratan Rai Sur <ratan.r.sur@gmail.com>
Date:   Mon Apr 27 10:39:03 2020 -0400

    remove unnecessary persist (#569)
    
    Signed-off-by: Ratan Rai Sur <ratan.r.sur@gmail.com>

diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetBlockImporter.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetBlockImporter.java
index 0ad46bd7c..efb28b892 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetBlockImporter.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetBlockImporter.java
@@ -16,7 +16,6 @@ package org.hyperledger.besu.ethereum.mainnet;
 
 import org.hyperledger.besu.ethereum.BlockValidator;
 import org.hyperledger.besu.ethereum.ProtocolContext;
-import org.hyperledger.besu.ethereum.chain.MutableBlockchain;
 import org.hyperledger.besu.ethereum.core.Block;
 import org.hyperledger.besu.ethereum.core.BlockImporter;
 import org.hyperledger.besu.ethereum.core.TransactionReceipt;
@@ -46,20 +45,13 @@ public class MainnetBlockImporter<C> implements BlockImporter<C> {
         blockValidator.validateAndProcessBlock(
             context, block, headerValidationMode, ommerValidationMode);
 
-    outputs.ifPresent(processingOutputs -> persistState(processingOutputs, block, context));
+    outputs.ifPresent(
+        processingOutputs ->
+            context.getBlockchain().appendBlock(block, processingOutputs.receipts));
 
     return outputs.isPresent();
   }
 
-  private void persistState(
-      final BlockValidator.BlockProcessingOutputs processingOutputs,
-      final Block block,
-      final ProtocolContext<C> context) {
-    processingOutputs.worldState.persist();
-    final MutableBlockchain blockchain = context.getBlockchain();
-    blockchain.appendBlock(block, processingOutputs.receipts);
-  }
-
   @Override
   public boolean fastImportBlock(
       final ProtocolContext<C> context,