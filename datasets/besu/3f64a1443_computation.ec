commit 3f64a144320d21535714894aec57a1a35c250d3c
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Thu Aug 20 10:37:18 2020 -0600

    Fix  memory expansion bounds checking (#1322)
    
    When a CALL series operation has an erroneous input offset (such as
    starting at a ETH address instead of a real offset) we threw an
    ArithmeticException.
    
    * Restore the old memory bounds checking on memory expansion
    * Treat these formerly uncaught exceptions as invalid transactions and
      report errors with a stack trace and custom halt reason.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetTransactionProcessor.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetTransactionProcessor.java
index 75cc1c6fd..f8322f105 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetTransactionProcessor.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/MainnetTransactionProcessor.java
@@ -27,6 +27,7 @@ import org.hyperledger.besu.ethereum.core.Wei;
 import org.hyperledger.besu.ethereum.core.WorldUpdater;
 import org.hyperledger.besu.ethereum.core.fees.CoinbaseFeePriceCalculator;
 import org.hyperledger.besu.ethereum.core.fees.TransactionPriceCalculator;
+import org.hyperledger.besu.ethereum.mainnet.TransactionValidator.TransactionInvalidReason;
 import org.hyperledger.besu.ethereum.vm.BlockHashLookup;
 import org.hyperledger.besu.ethereum.vm.Code;
 import org.hyperledger.besu.ethereum.vm.GasCalculator;
@@ -208,193 +209,204 @@ public class MainnetTransactionProcessor implements TransactionProcessor {
       final BlockHashLookup blockHashLookup,
       final Boolean isPersistingPrivateState,
       final TransactionValidationParams transactionValidationParams) {
-    LOG.trace("Starting execution of {}", transaction);
-
-    ValidationResult<TransactionValidator.TransactionInvalidReason> validationResult =
-        transactionValidator.validate(transaction, blockHeader.getBaseFee());
-    // Make sure the transaction is intrinsically valid before trying to
-    // compare against a sender account (because the transaction may not
-    // be signed correctly to extract the sender).
-    if (!validationResult.isValid()) {
-      LOG.warn("Invalid transaction: {}", validationResult.getErrorMessage());
-      return Result.invalid(validationResult);
-    }
+    try {
+      LOG.trace("Starting execution of {}", transaction);
+
+      ValidationResult<TransactionValidator.TransactionInvalidReason> validationResult =
+          transactionValidator.validate(transaction, blockHeader.getBaseFee());
+      // Make sure the transaction is intrinsically valid before trying to
+      // compare against a sender account (because the transaction may not
+      // be signed correctly to extract the sender).
+      if (!validationResult.isValid()) {
+        LOG.warn("Invalid transaction: {}", validationResult.getErrorMessage());
+        return Result.invalid(validationResult);
+      }
 
-    final Address senderAddress = transaction.getSender();
-    final DefaultEvmAccount sender = worldState.getOrCreate(senderAddress);
-    validationResult =
-        transactionValidator.validateForSender(transaction, sender, transactionValidationParams);
-    if (!validationResult.isValid()) {
-      LOG.debug("Invalid transaction: {}", validationResult.getErrorMessage());
-      return Result.invalid(validationResult);
-    }
+      final Address senderAddress = transaction.getSender();
+      final DefaultEvmAccount sender = worldState.getOrCreate(senderAddress);
+      validationResult =
+          transactionValidator.validateForSender(transaction, sender, transactionValidationParams);
+      if (!validationResult.isValid()) {
+        LOG.debug("Invalid transaction: {}", validationResult.getErrorMessage());
+        return Result.invalid(validationResult);
+      }
 
-    final MutableAccount senderMutableAccount = sender.getMutable();
-    final long previousNonce = senderMutableAccount.incrementNonce();
-    final Wei transactionGasPrice =
-        transactionPriceCalculator.price(transaction, blockHeader.getBaseFee());
-    LOG.trace(
-        "Incremented sender {} nonce ({} -> {})", senderAddress, previousNonce, sender.getNonce());
-
-    final Wei upfrontGasCost = transaction.getUpfrontGasCost(transactionGasPrice);
-    final Wei previousBalance = senderMutableAccount.decrementBalance(upfrontGasCost);
-    LOG.trace(
-        "Deducted sender {} upfront gas cost {} ({} -> {})",
-        senderAddress,
-        upfrontGasCost,
-        previousBalance,
-        sender.getBalance());
-
-    final Gas intrinsicGas = gasCalculator.transactionIntrinsicGasCost(transaction);
-    final Gas gasAvailable = Gas.of(transaction.getGasLimit()).minus(intrinsicGas);
-    LOG.trace(
-        "Gas available for execution {} = {} - {} (limit - intrinsic)",
-        gasAvailable,
-        transaction.getGasLimit(),
-        intrinsicGas);
-
-    final WorldUpdater worldUpdater = worldState.updater();
-    final MessageFrame initialFrame;
-    final Deque<MessageFrame> messageFrameStack = new ArrayDeque<>();
-    final ReturnStack returnStack = new ReturnStack();
-
-    if (transaction.isContractCreation()) {
-      final Address contractAddress =
-          Address.contractAddress(senderAddress, sender.getNonce() - 1L);
-
-      initialFrame =
-          MessageFrame.builder()
-              .type(MessageFrame.Type.CONTRACT_CREATION)
-              .messageFrameStack(messageFrameStack)
-              .returnStack(returnStack)
-              .blockchain(blockchain)
-              .worldState(worldUpdater.updater())
-              .initialGas(gasAvailable)
-              .address(contractAddress)
-              .originator(senderAddress)
-              .contract(contractAddress)
-              .contractAccountVersion(createContractAccountVersion)
-              .gasPrice(transactionGasPrice)
-              .inputData(Bytes.EMPTY)
-              .sender(senderAddress)
-              .value(transaction.getValue())
-              .apparentValue(transaction.getValue())
-              .code(new Code(transaction.getPayload()))
-              .blockHeader(blockHeader)
-              .depth(0)
-              .completer(c -> {})
-              .miningBeneficiary(miningBeneficiary)
-              .blockHashLookup(blockHashLookup)
-              .isPersistingPrivateState(isPersistingPrivateState)
-              .maxStackSize(maxStackSize)
-              .transactionHash(transaction.getHash())
-              .build();
-
-    } else {
-      final Address to = transaction.getTo().get();
-      final Account contract = worldState.get(to);
-
-      initialFrame =
-          MessageFrame.builder()
-              .type(MessageFrame.Type.MESSAGE_CALL)
-              .messageFrameStack(messageFrameStack)
-              .returnStack(returnStack)
-              .blockchain(blockchain)
-              .worldState(worldUpdater.updater())
-              .initialGas(gasAvailable)
-              .address(to)
-              .originator(senderAddress)
-              .contract(to)
-              .contractAccountVersion(
-                  contract != null ? contract.getVersion() : Account.DEFAULT_VERSION)
-              .gasPrice(transactionGasPrice)
-              .inputData(transaction.getPayload())
-              .sender(senderAddress)
-              .value(transaction.getValue())
-              .apparentValue(transaction.getValue())
-              .code(new Code(contract != null ? contract.getCode() : Bytes.EMPTY))
-              .blockHeader(blockHeader)
-              .depth(0)
-              .completer(c -> {})
-              .miningBeneficiary(miningBeneficiary)
-              .blockHashLookup(blockHashLookup)
-              .maxStackSize(maxStackSize)
-              .isPersistingPrivateState(isPersistingPrivateState)
-              .transactionHash(transaction.getHash())
-              .build();
-    }
+      final MutableAccount senderMutableAccount = sender.getMutable();
+      final long previousNonce = senderMutableAccount.incrementNonce();
+      final Wei transactionGasPrice =
+          transactionPriceCalculator.price(transaction, blockHeader.getBaseFee());
+      LOG.trace(
+          "Incremented sender {} nonce ({} -> {})",
+          senderAddress,
+          previousNonce,
+          sender.getNonce());
 
-    messageFrameStack.addFirst(initialFrame);
+      final Wei upfrontGasCost = transaction.getUpfrontGasCost(transactionGasPrice);
+      final Wei previousBalance = senderMutableAccount.decrementBalance(upfrontGasCost);
+      LOG.trace(
+          "Deducted sender {} upfront gas cost {} ({} -> {})",
+          senderAddress,
+          upfrontGasCost,
+          previousBalance,
+          sender.getBalance());
+
+      final Gas intrinsicGas = gasCalculator.transactionIntrinsicGasCost(transaction);
+      final Gas gasAvailable = Gas.of(transaction.getGasLimit()).minus(intrinsicGas);
+      LOG.trace(
+          "Gas available for execution {} = {} - {} (limit - intrinsic)",
+          gasAvailable,
+          transaction.getGasLimit(),
+          intrinsicGas);
+
+      final WorldUpdater worldUpdater = worldState.updater();
+      final MessageFrame initialFrame;
+      final Deque<MessageFrame> messageFrameStack = new ArrayDeque<>();
+      final ReturnStack returnStack = new ReturnStack();
+
+      if (transaction.isContractCreation()) {
+        final Address contractAddress =
+            Address.contractAddress(senderAddress, sender.getNonce() - 1L);
+
+        initialFrame =
+            MessageFrame.builder()
+                .type(MessageFrame.Type.CONTRACT_CREATION)
+                .messageFrameStack(messageFrameStack)
+                .returnStack(returnStack)
+                .blockchain(blockchain)
+                .worldState(worldUpdater.updater())
+                .initialGas(gasAvailable)
+                .address(contractAddress)
+                .originator(senderAddress)
+                .contract(contractAddress)
+                .contractAccountVersion(createContractAccountVersion)
+                .gasPrice(transactionGasPrice)
+                .inputData(Bytes.EMPTY)
+                .sender(senderAddress)
+                .value(transaction.getValue())
+                .apparentValue(transaction.getValue())
+                .code(new Code(transaction.getPayload()))
+                .blockHeader(blockHeader)
+                .depth(0)
+                .completer(c -> {})
+                .miningBeneficiary(miningBeneficiary)
+                .blockHashLookup(blockHashLookup)
+                .isPersistingPrivateState(isPersistingPrivateState)
+                .maxStackSize(maxStackSize)
+                .transactionHash(transaction.getHash())
+                .build();
+
+      } else {
+        final Address to = transaction.getTo().get();
+        final Account contract = worldState.get(to);
+
+        initialFrame =
+            MessageFrame.builder()
+                .type(MessageFrame.Type.MESSAGE_CALL)
+                .messageFrameStack(messageFrameStack)
+                .returnStack(returnStack)
+                .blockchain(blockchain)
+                .worldState(worldUpdater.updater())
+                .initialGas(gasAvailable)
+                .address(to)
+                .originator(senderAddress)
+                .contract(to)
+                .contractAccountVersion(
+                    contract != null ? contract.getVersion() : Account.DEFAULT_VERSION)
+                .gasPrice(transactionGasPrice)
+                .inputData(transaction.getPayload())
+                .sender(senderAddress)
+                .value(transaction.getValue())
+                .apparentValue(transaction.getValue())
+                .code(new Code(contract != null ? contract.getCode() : Bytes.EMPTY))
+                .blockHeader(blockHeader)
+                .depth(0)
+                .completer(c -> {})
+                .miningBeneficiary(miningBeneficiary)
+                .blockHashLookup(blockHashLookup)
+                .maxStackSize(maxStackSize)
+                .isPersistingPrivateState(isPersistingPrivateState)
+                .transactionHash(transaction.getHash())
+                .build();
+      }
 
-    while (!messageFrameStack.isEmpty()) {
-      process(messageFrameStack.peekFirst(), operationTracer);
-    }
+      messageFrameStack.addFirst(initialFrame);
 
-    if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
-      worldUpdater.commit();
-    }
+      while (!messageFrameStack.isEmpty()) {
+        process(messageFrameStack.peekFirst(), operationTracer);
+      }
 
-    if (LOG.isTraceEnabled()) {
-      LOG.trace(
-          "Gas used by transaction: {}, by message call/contract creation: {}",
-          () -> Gas.of(transaction.getGasLimit()).minus(initialFrame.getRemainingGas()),
-          () -> gasAvailable.minus(initialFrame.getRemainingGas()));
-    }
+      if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
+        worldUpdater.commit();
+      }
 
-    // Refund the sender by what we should and pay the miner fee (note that we're doing them one
-    // after the other so that if it is the same account somehow, we end up with the right result)
-    final Gas selfDestructRefund =
-        gasCalculator.getSelfDestructRefundAmount().times(initialFrame.getSelfDestructs().size());
-    final Gas refundGas = initialFrame.getGasRefund().plus(selfDestructRefund);
-    final Gas refunded = refunded(transaction, initialFrame.getRemainingGas(), refundGas);
-    final Wei refundedWei = refunded.priceFor(transactionGasPrice);
-    senderMutableAccount.incrementBalance(refundedWei);
-
-    final Gas gasUsedByTransaction =
-        Gas.of(transaction.getGasLimit()).minus(initialFrame.getRemainingGas());
-
-    final MutableAccount coinbase = worldState.getOrCreate(miningBeneficiary).getMutable();
-    final Gas coinbaseFee = Gas.of(transaction.getGasLimit()).minus(refunded);
-    if (blockHeader.getBaseFee().isPresent() && transaction.isEIP1559Transaction()) {
-      final Wei baseFee = Wei.of(blockHeader.getBaseFee().get());
-      if (transactionGasPrice.compareTo(baseFee) < 0) {
-        return Result.failed(
-            gasUsedByTransaction.toLong(),
-            refunded.toLong(),
-            ValidationResult.invalid(
-                TransactionValidator.TransactionInvalidReason.TRANSACTION_PRICE_TOO_LOW,
-                "transaction price must be greater than base fee"),
-            Optional.empty());
+      if (LOG.isTraceEnabled()) {
+        LOG.trace(
+            "Gas used by transaction: {}, by message call/contract creation: {}",
+            () -> Gas.of(transaction.getGasLimit()).minus(initialFrame.getRemainingGas()),
+            () -> gasAvailable.minus(initialFrame.getRemainingGas()));
       }
-    }
-    final CoinbaseFeePriceCalculator coinbaseCreditService =
-        transaction.isFrontierTransaction()
-            ? CoinbaseFeePriceCalculator.frontier()
-            : coinbaseFeePriceCalculator;
-    final Wei coinbaseWeiDelta =
-        coinbaseCreditService.price(coinbaseFee, transactionGasPrice, blockHeader.getBaseFee());
 
-    coinbase.incrementBalance(coinbaseWeiDelta);
+      // Refund the sender by what we should and pay the miner fee (note that we're doing them one
+      // after the other so that if it is the same account somehow, we end up with the right result)
+      final Gas selfDestructRefund =
+          gasCalculator.getSelfDestructRefundAmount().times(initialFrame.getSelfDestructs().size());
+      final Gas refundGas = initialFrame.getGasRefund().plus(selfDestructRefund);
+      final Gas refunded = refunded(transaction, initialFrame.getRemainingGas(), refundGas);
+      final Wei refundedWei = refunded.priceFor(transactionGasPrice);
+      senderMutableAccount.incrementBalance(refundedWei);
+
+      final Gas gasUsedByTransaction =
+          Gas.of(transaction.getGasLimit()).minus(initialFrame.getRemainingGas());
+
+      final MutableAccount coinbase = worldState.getOrCreate(miningBeneficiary).getMutable();
+      final Gas coinbaseFee = Gas.of(transaction.getGasLimit()).minus(refunded);
+      if (blockHeader.getBaseFee().isPresent() && transaction.isEIP1559Transaction()) {
+        final Wei baseFee = Wei.of(blockHeader.getBaseFee().get());
+        if (transactionGasPrice.compareTo(baseFee) < 0) {
+          return Result.failed(
+              gasUsedByTransaction.toLong(),
+              refunded.toLong(),
+              ValidationResult.invalid(
+                  TransactionValidator.TransactionInvalidReason.TRANSACTION_PRICE_TOO_LOW,
+                  "transaction price must be greater than base fee"),
+              Optional.empty());
+        }
+      }
+      final CoinbaseFeePriceCalculator coinbaseCreditService =
+          transaction.isFrontierTransaction()
+              ? CoinbaseFeePriceCalculator.frontier()
+              : coinbaseFeePriceCalculator;
+      final Wei coinbaseWeiDelta =
+          coinbaseCreditService.price(coinbaseFee, transactionGasPrice, blockHeader.getBaseFee());
 
-    initialFrame.getSelfDestructs().forEach(worldState::deleteAccount);
+      coinbase.incrementBalance(coinbaseWeiDelta);
 
-    if (clearEmptyAccounts) {
-      clearEmptyAccounts(worldState);
-    }
+      initialFrame.getSelfDestructs().forEach(worldState::deleteAccount);
 
-    if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
-      return Result.successful(
-          initialFrame.getLogs(),
-          gasUsedByTransaction.toLong(),
-          refunded.toLong(),
-          initialFrame.getOutputData(),
-          validationResult);
-    } else {
-      return Result.failed(
-          gasUsedByTransaction.toLong(),
-          refunded.toLong(),
-          validationResult,
-          initialFrame.getRevertReason());
+      if (clearEmptyAccounts) {
+        clearEmptyAccounts(worldState);
+      }
+
+      if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
+        return Result.successful(
+            initialFrame.getLogs(),
+            gasUsedByTransaction.toLong(),
+            refunded.toLong(),
+            initialFrame.getOutputData(),
+            validationResult);
+      } else {
+        return Result.failed(
+            gasUsedByTransaction.toLong(),
+            refunded.toLong(),
+            validationResult,
+            initialFrame.getRevertReason());
+      }
+    } catch (final RuntimeException re) {
+      LOG.error("Critical Exception Processing Transaction", re);
+      return Result.invalid(
+          ValidationResult.invalid(
+              TransactionInvalidReason.INTERNAL_ERROR,
+              "Internal Error in Besu - " + re.toString()));
     }
   }
 
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/TransactionValidator.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/TransactionValidator.java
index 15bf06e6e..2408df3c2 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/TransactionValidator.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/mainnet/TransactionValidator.java
@@ -87,6 +87,7 @@ public interface TransactionValidator {
     GAS_PRICE_TOO_LOW,
     TX_FEECAP_EXCEEDED,
     PRIVATE_VALUE_NOT_ZERO,
-    PRIVATE_UNIMPLEMENTED_TRANSACTION_TYPE;
+    PRIVATE_UNIMPLEMENTED_TRANSACTION_TYPE,
+    INTERNAL_ERROR;
   }
 }
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/PrivateTransactionProcessor.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/PrivateTransactionProcessor.java
index e34d4dc57..00506bcba 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/PrivateTransactionProcessor.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/PrivateTransactionProcessor.java
@@ -29,6 +29,7 @@ import org.hyperledger.besu.ethereum.core.WorldUpdater;
 import org.hyperledger.besu.ethereum.mainnet.AbstractMessageProcessor;
 import org.hyperledger.besu.ethereum.mainnet.TransactionProcessor;
 import org.hyperledger.besu.ethereum.mainnet.TransactionValidator;
+import org.hyperledger.besu.ethereum.mainnet.TransactionValidator.TransactionInvalidReason;
 import org.hyperledger.besu.ethereum.mainnet.ValidationResult;
 import org.hyperledger.besu.ethereum.vm.BlockHashLookup;
 import org.hyperledger.besu.ethereum.vm.Code;
@@ -213,127 +214,135 @@ public class PrivateTransactionProcessor {
       final OperationTracer operationTracer,
       final BlockHashLookup blockHashLookup,
       final Bytes privacyGroupId) {
-    LOG.trace("Starting private execution of {}", transaction);
-
-    final Address senderAddress = transaction.getSender();
-    final DefaultEvmAccount maybePrivateSender = privateWorldState.getAccount(senderAddress);
-    final MutableAccount sender =
-        maybePrivateSender != null
-            ? maybePrivateSender.getMutable()
-            : privateWorldState.createAccount(senderAddress, 0, Wei.ZERO).getMutable();
-
-    final ValidationResult<TransactionValidator.TransactionInvalidReason> validationResult =
-        privateTransactionValidator.validate(transaction, sender.getNonce(), false);
-    if (!validationResult.isValid()) {
-      return Result.invalid(validationResult);
-    }
-
-    final long previousNonce = sender.incrementNonce();
-    LOG.trace(
-        "Incremented private sender {} nonce ({} -> {})",
-        senderAddress,
-        previousNonce,
-        sender.getNonce());
-
-    final MessageFrame initialFrame;
-    final Deque<MessageFrame> messageFrameStack = new ArrayDeque<>();
-
-    final WorldUpdater mutablePrivateWorldStateUpdater =
-        new DefaultMutablePrivateWorldStateUpdater(publicWorldState, privateWorldState);
-
-    final ReturnStack returnStack = new ReturnStack();
-
-    if (transaction.isContractCreation()) {
-      final Address privateContractAddress =
-          Address.privateContractAddress(senderAddress, previousNonce, privacyGroupId);
-
-      LOG.debug(
-          "Calculated contract address {} from sender {} with nonce {} and privacy group {}",
-          privateContractAddress.toString(),
+    try {
+      LOG.trace("Starting private execution of {}", transaction);
+
+      final Address senderAddress = transaction.getSender();
+      final DefaultEvmAccount maybePrivateSender = privateWorldState.getAccount(senderAddress);
+      final MutableAccount sender =
+          maybePrivateSender != null
+              ? maybePrivateSender.getMutable()
+              : privateWorldState.createAccount(senderAddress, 0, Wei.ZERO).getMutable();
+
+      final ValidationResult<TransactionValidator.TransactionInvalidReason> validationResult =
+          privateTransactionValidator.validate(transaction, sender.getNonce(), false);
+      if (!validationResult.isValid()) {
+        return Result.invalid(validationResult);
+      }
+
+      final long previousNonce = sender.incrementNonce();
+      LOG.trace(
+          "Incremented private sender {} nonce ({} -> {})",
           senderAddress,
           previousNonce,
-          privacyGroupId.toString());
-
-      initialFrame =
-          MessageFrame.builder()
-              .type(MessageFrame.Type.CONTRACT_CREATION)
-              .messageFrameStack(messageFrameStack)
-              .returnStack(returnStack)
-              .blockchain(blockchain)
-              .worldState(mutablePrivateWorldStateUpdater)
-              .address(privateContractAddress)
-              .originator(senderAddress)
-              .contract(privateContractAddress)
-              .contractAccountVersion(createContractAccountVersion)
-              .initialGas(Gas.MAX_VALUE)
-              .gasPrice(transaction.getGasPrice())
-              .inputData(Bytes.EMPTY)
-              .sender(senderAddress)
-              .value(transaction.getValue())
-              .apparentValue(transaction.getValue())
-              .code(new Code(transaction.getPayload()))
-              .blockHeader(blockHeader)
-              .depth(0)
-              .completer(c -> {})
-              .miningBeneficiary(miningBeneficiary)
-              .blockHashLookup(blockHashLookup)
-              .maxStackSize(maxStackSize)
-              .transactionHash(pmtHash)
-              .build();
-
-    } else {
-      final Address to = transaction.getTo().get();
-      final Account contract = privateWorldState.get(to);
-
-      initialFrame =
-          MessageFrame.builder()
-              .type(MessageFrame.Type.MESSAGE_CALL)
-              .messageFrameStack(messageFrameStack)
-              .returnStack(returnStack)
-              .blockchain(blockchain)
-              .worldState(mutablePrivateWorldStateUpdater)
-              .address(to)
-              .originator(senderAddress)
-              .contract(to)
-              .contractAccountVersion(
-                  contract != null ? contract.getVersion() : Account.DEFAULT_VERSION)
-              .initialGas(Gas.MAX_VALUE)
-              .gasPrice(transaction.getGasPrice())
-              .inputData(transaction.getPayload())
-              .sender(senderAddress)
-              .value(transaction.getValue())
-              .apparentValue(transaction.getValue())
-              .code(new Code(contract != null ? contract.getCode() : Bytes.EMPTY))
-              .blockHeader(blockHeader)
-              .depth(0)
-              .completer(c -> {})
-              .miningBeneficiary(miningBeneficiary)
-              .blockHashLookup(blockHashLookup)
-              .maxStackSize(maxStackSize)
-              .transactionHash(pmtHash)
-              .build();
-    }
-
-    messageFrameStack.addFirst(initialFrame);
-
-    while (!messageFrameStack.isEmpty()) {
-      process(messageFrameStack.peekFirst(), operationTracer);
-    }
-
-    if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
-      mutablePrivateWorldStateUpdater.commit();
-    }
-
-    if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
-      return Result.successful(
-          initialFrame.getLogs(), 0, 0, initialFrame.getOutputData(), ValidationResult.valid());
-    } else {
-      return Result.failed(
-          0,
-          0,
+          sender.getNonce());
+
+      final MessageFrame initialFrame;
+      final Deque<MessageFrame> messageFrameStack = new ArrayDeque<>();
+
+      final WorldUpdater mutablePrivateWorldStateUpdater =
+          new DefaultMutablePrivateWorldStateUpdater(publicWorldState, privateWorldState);
+
+      final ReturnStack returnStack = new ReturnStack();
+
+      if (transaction.isContractCreation()) {
+        final Address privateContractAddress =
+            Address.privateContractAddress(senderAddress, previousNonce, privacyGroupId);
+
+        LOG.debug(
+            "Calculated contract address {} from sender {} with nonce {} and privacy group {}",
+            privateContractAddress.toString(),
+            senderAddress,
+            previousNonce,
+            privacyGroupId.toString());
+
+        initialFrame =
+            MessageFrame.builder()
+                .type(MessageFrame.Type.CONTRACT_CREATION)
+                .messageFrameStack(messageFrameStack)
+                .returnStack(returnStack)
+                .blockchain(blockchain)
+                .worldState(mutablePrivateWorldStateUpdater)
+                .address(privateContractAddress)
+                .originator(senderAddress)
+                .contract(privateContractAddress)
+                .contractAccountVersion(createContractAccountVersion)
+                .initialGas(Gas.MAX_VALUE)
+                .gasPrice(transaction.getGasPrice())
+                .inputData(Bytes.EMPTY)
+                .sender(senderAddress)
+                .value(transaction.getValue())
+                .apparentValue(transaction.getValue())
+                .code(new Code(transaction.getPayload()))
+                .blockHeader(blockHeader)
+                .depth(0)
+                .completer(c -> {})
+                .miningBeneficiary(miningBeneficiary)
+                .blockHashLookup(blockHashLookup)
+                .maxStackSize(maxStackSize)
+                .transactionHash(pmtHash)
+                .build();
+
+      } else {
+        final Address to = transaction.getTo().get();
+        final Account contract = privateWorldState.get(to);
+
+        initialFrame =
+            MessageFrame.builder()
+                .type(MessageFrame.Type.MESSAGE_CALL)
+                .messageFrameStack(messageFrameStack)
+                .returnStack(returnStack)
+                .blockchain(blockchain)
+                .worldState(mutablePrivateWorldStateUpdater)
+                .address(to)
+                .originator(senderAddress)
+                .contract(to)
+                .contractAccountVersion(
+                    contract != null ? contract.getVersion() : Account.DEFAULT_VERSION)
+                .initialGas(Gas.MAX_VALUE)
+                .gasPrice(transaction.getGasPrice())
+                .inputData(transaction.getPayload())
+                .sender(senderAddress)
+                .value(transaction.getValue())
+                .apparentValue(transaction.getValue())
+                .code(new Code(contract != null ? contract.getCode() : Bytes.EMPTY))
+                .blockHeader(blockHeader)
+                .depth(0)
+                .completer(c -> {})
+                .miningBeneficiary(miningBeneficiary)
+                .blockHashLookup(blockHashLookup)
+                .maxStackSize(maxStackSize)
+                .transactionHash(pmtHash)
+                .build();
+      }
+
+      messageFrameStack.addFirst(initialFrame);
+
+      while (!messageFrameStack.isEmpty()) {
+        process(messageFrameStack.peekFirst(), operationTracer);
+      }
+
+      if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
+        mutablePrivateWorldStateUpdater.commit();
+      }
+
+      if (initialFrame.getState() == MessageFrame.State.COMPLETED_SUCCESS) {
+        return Result.successful(
+            initialFrame.getLogs(), 0, 0, initialFrame.getOutputData(), ValidationResult.valid());
+      } else {
+        return Result.failed(
+            0,
+            0,
+            ValidationResult.invalid(
+                TransactionValidator.TransactionInvalidReason.PRIVATE_TRANSACTION_FAILED),
+            initialFrame.getRevertReason());
+      }
+    } catch (final RuntimeException re) {
+      LOG.error("Critical Exception Processing Transaction", re);
+      return Result.invalid(
           ValidationResult.invalid(
-              TransactionValidator.TransactionInvalidReason.PRIVATE_TRANSACTION_FAILED),
-          initialFrame.getRevertReason());
+              TransactionInvalidReason.INTERNAL_ERROR,
+              "Internal Error in Besu - " + re.toString()));
     }
   }
 
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/AbstractCallOperation.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/AbstractCallOperation.java
index e1f7133d5..77cfddd30 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/AbstractCallOperation.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/AbstractCallOperation.java
@@ -171,8 +171,8 @@ public abstract class AbstractCallOperation extends AbstractOperation {
       final Account account = frame.getWorldState().get(frame.getRecipientAddress());
       final Wei balance = account.getBalance();
       if (value(frame).compareTo(balance) > 0 || frame.getMessageStackDepth() >= 1024) {
-        frame.expandMemory(inputDataOffset(frame).intValue(), inputDataLength(frame).intValue());
-        frame.expandMemory(outputDataOffset(frame).intValue(), outputDataLength(frame).intValue());
+        frame.expandMemory(inputDataOffset(frame), inputDataLength(frame));
+        frame.expandMemory(outputDataOffset(frame), outputDataLength(frame));
         frame.incrementRemainingGas(gasAvailableForChildCall(frame).plus(cost));
         frame.popStackItems(getStackItemsConsumed());
         frame.pushStackItem(Bytes32.ZERO);
@@ -227,7 +227,7 @@ public abstract class AbstractCallOperation extends AbstractOperation {
     final int outputSizeAsInt = outputSize.intValue();
 
     if (outputSizeAsInt > outputData.size()) {
-      frame.expandMemory(outputOffset.intValue(), outputSizeAsInt);
+      frame.expandMemory(outputOffset, outputSize);
       frame.writeMemory(outputOffset, UInt256.valueOf(outputData.size()), outputData, true);
     } else {
       frame.writeMemory(outputOffset, outputSize, outputData, true);
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/EVM.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/EVM.java
index 2c7da720c..9fd638d60 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/EVM.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/EVM.java
@@ -84,7 +84,7 @@ public class EVM {
           logState(frame, result.getGasCost().orElse(Gas.ZERO));
           final Optional<ExceptionalHaltReason> haltReason = result.getHaltReason();
           if (haltReason.isPresent()) {
-            LOG.trace("MessageFrame evaluation halted because of {}", haltReason);
+            LOG.trace("MessageFrame evaluation halted because of {}", haltReason.get());
             frame.setExceptionalHaltReason(haltReason);
             frame.setState(State.EXCEPTIONAL_HALT);
           } else if (result.getGasCost().isPresent()) {
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/Memory.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/Memory.java
index 333829926..94be53721 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/Memory.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/Memory.java
@@ -135,16 +135,28 @@ public class Memory {
   /**
    * Expands the active words to accommodate the specified byte position.
    *
-   * @param address The location in memory to start with.
+   * @param offset The location in memory to start with.
    * @param numBytes The number of bytes to get.
    */
-  void ensureCapacityForBytes(final int address, final int numBytes) {
+  void ensureCapacityForBytes(final UInt256 offset, final UInt256 numBytes) {
+    if (!offset.fitsInt()) return;
+    if (!numBytes.fitsInt()) return;
+    ensureCapacityForBytes(offset.intValue(), numBytes.intValue());
+  }
+
+  /**
+   * Expands the active words to accommodate the specified byte position.
+   *
+   * @param offset The location in memory to start with.
+   * @param numBytes The number of bytes to get.
+   */
+  void ensureCapacityForBytes(final int offset, final int numBytes) {
     // Do not increase the memory capacity if no bytes are being written
     // regardless of what the address may be.
     if (numBytes == 0) {
       return;
     }
-    final int lastByteIndex = Math.addExact(address, numBytes);
+    final int lastByteIndex = Math.addExact(offset, numBytes);
     final int lastWordRequired = ((lastByteIndex - 1) / Bytes32.SIZE);
     maybeExpandCapacity(lastWordRequired + 1);
   }
diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/MessageFrame.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/MessageFrame.java
index 326448603..14b2cd439 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/MessageFrame.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/vm/MessageFrame.java
@@ -550,7 +550,7 @@ public class MessageFrame {
    * @param offset The offset in memory
    * @param length The length of the memory access
    */
-  public void expandMemory(final int offset, final int length) {
+  public void expandMemory(final UInt256 offset, final UInt256 length) {
     memory.ensureCapacityForBytes(offset, length);
   }
 