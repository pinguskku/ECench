commit c069060d2bf87042da6761ba734139f25353ae61
Author: Danno Ferrin <danno.ferrin@shemnon.com>
Date:   Tue Apr 9 11:05:53 2019 -0600

    Reduce memory usage in import (#1239)
    
    There is no need to keep entire blocks during import after they have
    been imported.  Keep just the hashes instead.
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/BlockHandler.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/BlockHandler.java
index 0b36dd1dc..52433b5e0 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/BlockHandler.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/BlockHandler.java
@@ -13,16 +13,19 @@
 package tech.pegasys.pantheon.ethereum.eth.sync;
 
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 
 import java.util.List;
 import java.util.concurrent.CompletableFuture;
 
 public interface BlockHandler<B> {
-  CompletableFuture<List<B>> downloadBlocks(final List<BlockHeader> headers);
+  CompletableFuture<List<B>> downloadBlocks(List<BlockHeader> headers);
 
-  CompletableFuture<List<B>> validateAndImportBlocks(final List<B> blocks);
+  CompletableFuture<List<B>> validateAndImportBlocks(List<B> blocks);
 
-  long extractBlockNumber(final B block);
+  long extractBlockNumber(B block);
+
+  Hash extractBlockHash(B block);
 
   CompletableFuture<Void> executeParallelCalculations(List<B> blocks);
 }
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/EthTaskChainDownloader.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/EthTaskChainDownloader.java
index 62eda51c8..2b0c5638e 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/EthTaskChainDownloader.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/EthTaskChainDownloader.java
@@ -14,8 +14,8 @@ package tech.pegasys.pantheon.ethereum.eth.sync;
 
 import static java.util.Collections.emptyList;
 
-import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthPeer;
 import tech.pegasys.pantheon.ethereum.eth.manager.exceptions.EthTaskException;
@@ -205,13 +205,13 @@ public class EthTaskChainDownloader<C> implements ChainDownloader {
     syncState.clearSyncTarget();
   }
 
-  private CompletableFuture<List<Block>> importBlocks(final List<BlockHeader> checkpointHeaders) {
+  private CompletableFuture<List<Hash>> importBlocks(final List<BlockHeader> checkpointHeaders) {
     if (checkpointHeaders.isEmpty()) {
       // No checkpoints to download
       return CompletableFuture.completedFuture(emptyList());
     }
 
-    final CompletableFuture<List<Block>> importedBlocks =
+    final CompletableFuture<List<Hash>> importedBlocks =
         blockImportTaskFactory.importBlocksForCheckpoints(checkpointHeaders);
 
     return importedBlocks.whenComplete(
@@ -261,7 +261,7 @@ public class EthTaskChainDownloader<C> implements ChainDownloader {
   }
 
   public interface BlockImportTaskFactory {
-    CompletableFuture<List<Block>> importBlocksForCheckpoints(
+    CompletableFuture<List<Hash>> importBlocksForCheckpoints(
         final List<BlockHeader> checkpointHeaders);
   }
 }
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java
index b40c39742..f2ddfcdce 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java
@@ -19,6 +19,7 @@ import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
 import tech.pegasys.pantheon.ethereum.core.BlockImporter;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.core.TransactionReceipt;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.sync.BlockHandler;
@@ -129,6 +130,11 @@ public class FastSyncBlockHandler<C> implements BlockHandler<BlockWithReceipts>
     return blockWithReceipt.getHeader().getNumber();
   }
 
+  @Override
+  public Hash extractBlockHash(final BlockWithReceipts block) {
+    return block.getHash();
+  }
+
   @Override
   public CompletableFuture<Void> executeParallelCalculations(final List<BlockWithReceipts> blocks) {
     return CompletableFuture.completedFuture(null);
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockImportTaskFactory.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockImportTaskFactory.java
index def15fb28..db1194374 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockImportTaskFactory.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockImportTaskFactory.java
@@ -15,8 +15,8 @@ package tech.pegasys.pantheon.ethereum.eth.sync.fastsync;
 import static java.util.Collections.emptyList;
 
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
-import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.sync.EthTaskChainDownloader.BlockImportTaskFactory;
 import tech.pegasys.pantheon.ethereum.eth.sync.SynchronizerConfiguration;
@@ -30,7 +30,6 @@ import tech.pegasys.pantheon.metrics.MetricsSystem;
 
 import java.util.List;
 import java.util.concurrent.CompletableFuture;
-import java.util.stream.Collectors;
 
 class FastSyncBlockImportTaskFactory<C> implements BlockImportTaskFactory {
 
@@ -61,7 +60,7 @@ class FastSyncBlockImportTaskFactory<C> implements BlockImportTaskFactory {
   }
 
   @Override
-  public CompletableFuture<List<Block>> importBlocksForCheckpoints(
+  public CompletableFuture<List<Hash>> importBlocksForCheckpoints(
       final List<BlockHeader> checkpointHeaders) {
     if (checkpointHeaders.size() < 2) {
       return CompletableFuture.completedFuture(emptyList());
@@ -94,10 +93,6 @@ class FastSyncBlockImportTaskFactory<C> implements BlockImportTaskFactory {
             detatchedValidationPolicy,
             checkpointHeaders,
             metricsSystem);
-    return importTask
-        .run()
-        .thenApply(
-            results ->
-                results.stream().map(BlockWithReceipts::getBlock).collect(Collectors.toList()));
+    return importTask.run();
   }
 }
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockHandler.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockHandler.java
index dd9282f57..10d86ef4d 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockHandler.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockHandler.java
@@ -15,6 +15,7 @@ package tech.pegasys.pantheon.ethereum.eth.sync.fullsync;
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.core.Transaction;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthScheduler;
@@ -77,6 +78,11 @@ public class FullSyncBlockHandler<C> implements BlockHandler<Block> {
     return block.getHeader().getNumber();
   }
 
+  @Override
+  public Hash extractBlockHash(final Block block) {
+    return block.getHash();
+  }
+
   @Override
   public CompletableFuture<Void> executeParallelCalculations(final List<Block> blocks) {
     final EthScheduler ethScheduler = ethContext.getScheduler();
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockImportTaskFactory.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockImportTaskFactory.java
index 5c42bab24..35fba43b8 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockImportTaskFactory.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fullsync/FullSyncBlockImportTaskFactory.java
@@ -15,6 +15,7 @@ package tech.pegasys.pantheon.ethereum.eth.sync.fullsync;
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.manager.task.AbstractPeerTask.PeerTaskResult;
 import tech.pegasys.pantheon.ethereum.eth.sync.EthTaskChainDownloader.BlockImportTaskFactory;
@@ -50,9 +51,9 @@ class FullSyncBlockImportTaskFactory<C> implements BlockImportTaskFactory {
   }
 
   @Override
-  public CompletableFuture<List<Block>> importBlocksForCheckpoints(
+  public CompletableFuture<List<Hash>> importBlocksForCheckpoints(
       final List<BlockHeader> checkpointHeaders) {
-    final CompletableFuture<List<Block>> importedBlocks;
+    final CompletableFuture<List<Hash>> importedHashes;
     if (checkpointHeaders.size() < 2) {
       // Download blocks without constraining the end block
       final ImportBlocksTask<C> importTask =
@@ -63,7 +64,7 @@ class FullSyncBlockImportTaskFactory<C> implements BlockImportTaskFactory {
               checkpointHeaders.get(0),
               config.downloaderChainSegmentSize(),
               metricsSystem);
-      importedBlocks = importTask.run().thenApply(PeerTaskResult::getResult);
+      importedHashes = importTask.run().thenApply(PeerTaskResult::getResult);
     } else {
       final ParallelImportChainSegmentTask<C, Block> importTask =
           ParallelImportChainSegmentTask.forCheckpoints(
@@ -76,8 +77,8 @@ class FullSyncBlockImportTaskFactory<C> implements BlockImportTaskFactory {
               () -> HeaderValidationMode.DETACHED_ONLY,
               checkpointHeaders,
               metricsSystem);
-      importedBlocks = importTask.run();
+      importedHashes = importTask.run();
     }
-    return importedBlocks;
+    return importedHashes;
   }
 }
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTask.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTask.java
index 4ed5a21e0..01dbb73de 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTask.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTask.java
@@ -15,6 +15,7 @@ package tech.pegasys.pantheon.ethereum.eth.sync.tasks;
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthPeer;
 import tech.pegasys.pantheon.ethereum.eth.manager.task.AbstractPeerTask;
@@ -29,6 +30,7 @@ import java.util.List;
 import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.function.Supplier;
+import java.util.stream.Collectors;
 
 import org.apache.logging.log4j.LogManager;
 import org.apache.logging.log4j.Logger;
@@ -38,7 +40,7 @@ import org.apache.logging.log4j.Logger;
  *
  * @param <C> the consensus algorithm context
  */
-public class ImportBlocksTask<C> extends AbstractPeerTask<List<Block>> {
+public class ImportBlocksTask<C> extends AbstractPeerTask<List<Hash>> {
   private static final Logger LOG = LogManager.getLogger();
 
   private final ProtocolContext<C> protocolContext;
@@ -92,7 +94,11 @@ public class ImportBlocksTask<C> extends AbstractPeerTask<List<Block>> {
                 result.get().completeExceptionally(t);
               } else {
                 LOG.debug("Import from block {} succeeded.", startNumber);
-                result.get().complete(new PeerTaskResult<>(peer, r));
+                result
+                    .get()
+                    .complete(
+                        new PeerTaskResult<>(
+                            peer, r.stream().map(Block::getHash).collect(Collectors.toList())));
               }
             });
   }
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelImportChainSegmentTask.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelImportChainSegmentTask.java
index b54356f9f..eb7bd2ece 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelImportChainSegmentTask.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelImportChainSegmentTask.java
@@ -14,6 +14,7 @@ package tech.pegasys.pantheon.ethereum.eth.sync.tasks;
 
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthContext;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthScheduler;
 import tech.pegasys.pantheon.ethereum.eth.manager.task.AbstractEthTask;
@@ -34,7 +35,7 @@ import java.util.stream.Collectors;
 import org.apache.logging.log4j.LogManager;
 import org.apache.logging.log4j.Logger;
 
-public class ParallelImportChainSegmentTask<C, B> extends AbstractEthTask<List<B>> {
+public class ParallelImportChainSegmentTask<C, B> extends AbstractEthTask<List<Hash>> {
   private static final Logger LOG = LogManager.getLogger();
 
   private final EthContext ethContext;
@@ -149,7 +150,7 @@ public class ParallelImportChainSegmentTask<C, B> extends AbstractEthTask<List<B
       final CompletableFuture<?> extractTxSignaturesFuture =
           scheduler.scheduleServiceTask(extractTxSignaturesTask);
       registerSubTask(extractTxSignaturesFuture);
-      final CompletableFuture<List<List<B>>> validateBodiesFuture =
+      final CompletableFuture<List<List<Hash>>> validateBodiesFuture =
           scheduler.scheduleServiceTask(validateAndImportBodiesTask);
       registerSubTask(validateBodiesFuture);
 
@@ -182,7 +183,7 @@ public class ParallelImportChainSegmentTask<C, B> extends AbstractEthTask<List<B
               cancelOnException.accept(null, e);
             } else if (r != null) {
               try {
-                final List<B> importedBlocks =
+                final List<Hash> importedBlocks =
                     validateBodiesFuture.get().stream()
                         .flatMap(Collection::stream)
                         .collect(Collectors.toList());
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelValidateAndImportBodiesTask.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelValidateAndImportBodiesTask.java
index 5dd357c07..0f1876bee 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelValidateAndImportBodiesTask.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ParallelValidateAndImportBodiesTask.java
@@ -12,6 +12,7 @@
  */
 package tech.pegasys.pantheon.ethereum.eth.sync.tasks;
 
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.eth.manager.task.AbstractPipelinedTask;
 import tech.pegasys.pantheon.ethereum.eth.sync.BlockHandler;
 import tech.pegasys.pantheon.metrics.MetricsSystem;
@@ -21,12 +22,13 @@ import java.util.Optional;
 import java.util.concurrent.BlockingQueue;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.ExecutionException;
+import java.util.stream.Collectors;
 
 import org.apache.logging.log4j.LogManager;
 import org.apache.logging.log4j.Logger;
 
 public class ParallelValidateAndImportBodiesTask<B>
-    extends AbstractPipelinedTask<List<B>, List<B>> {
+    extends AbstractPipelinedTask<List<B>, List<Hash>> {
   private static final Logger LOG = LogManager.getLogger();
 
   private final BlockHandler<B> blockHandler;
@@ -42,7 +44,7 @@ public class ParallelValidateAndImportBodiesTask<B>
   }
 
   @Override
-  protected Optional<List<B>> processStep(
+  protected Optional<List<Hash>> processStep(
       final List<B> blocks, final Optional<List<B>> previousBlocks) {
     final long firstBlock = blockHandler.extractBlockNumber(blocks.get(0));
     final long lastBlock = blockHandler.extractBlockNumber(blocks.get(blocks.size() - 1));
@@ -50,9 +52,12 @@ public class ParallelValidateAndImportBodiesTask<B>
     final CompletableFuture<List<B>> importedBlocksFuture =
         blockHandler.validateAndImportBlocks(blocks);
     try {
-      final List<B> downloadedBlocks = importedBlocksFuture.get();
+      final List<Hash> downloadedHashes =
+          importedBlocksFuture.get().stream()
+              .map(blockHandler::extractBlockHash)
+              .collect(Collectors.toList());
       LOG.info("Completed importing chain segment {} to {}", firstBlock, lastBlock);
-      return Optional.of(downloadedBlocks);
+      return Optional.of(downloadedHashes);
     } catch (final InterruptedException | ExecutionException e) {
       failExceptionally(e);
       return Optional.empty();
diff --git a/ethereum/eth/src/test/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTaskTest.java b/ethereum/eth/src/test/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTaskTest.java
index 4aa77cd1f..b7579c387 100644
--- a/ethereum/eth/src/test/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTaskTest.java
+++ b/ethereum/eth/src/test/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/ImportBlocksTaskTest.java
@@ -21,6 +21,7 @@ import tech.pegasys.pantheon.ethereum.chain.MutableBlockchain;
 import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockBody;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
+import tech.pegasys.pantheon.ethereum.core.Hash;
 import tech.pegasys.pantheon.ethereum.core.TransactionReceipt;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthPeer;
 import tech.pegasys.pantheon.ethereum.eth.manager.EthProtocolManagerTestUtil;
@@ -39,15 +40,15 @@ import java.util.ArrayList;
 import java.util.List;
 import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
-import java.util.concurrent.ExecutionException;
 import java.util.concurrent.atomic.AtomicBoolean;
 import java.util.concurrent.atomic.AtomicReference;
+import java.util.stream.Collectors;
 
 import com.google.common.collect.Lists;
 import org.junit.Test;
 
 public class ImportBlocksTaskTest
-    extends AbstractMessageTaskTest<List<Block>, PeerTaskResult<List<Block>>> {
+    extends AbstractMessageTaskTest<List<Block>, PeerTaskResult<List<Hash>>> {
 
   @Override
   protected List<Block> generateDataToBeRequested() {
@@ -64,7 +65,7 @@ public class ImportBlocksTaskTest
   }
 
   @Override
-  protected EthTask<PeerTaskResult<List<Block>>> createTask(final List<Block> requestedData) {
+  protected EthTask<PeerTaskResult<List<Hash>>> createTask(final List<Block> requestedData) {
     final Block firstBlock = requestedData.get(0);
     final MutableBlockchain shortBlockchain =
         createShortChain(firstBlock.getHeader().getNumber() - 1);
@@ -85,15 +86,15 @@ public class ImportBlocksTaskTest
   @Override
   protected void assertResultMatchesExpectation(
       final List<Block> requestedData,
-      final PeerTaskResult<List<Block>> response,
+      final PeerTaskResult<List<Hash>> response,
       final EthPeer respondingPeer) {
-    assertThat(response.getResult()).isEqualTo(requestedData);
+    assertThat(response.getResult())
+        .isEqualTo(requestedData.stream().map(Block::getHash).collect(Collectors.toList()));
     assertThat(response.getPeer()).isEqualTo(respondingPeer);
   }
 
   @Test
-  public void completesWhenPeerReturnsPartialResult()
-      throws ExecutionException, InterruptedException {
+  public void completesWhenPeerReturnsPartialResult() {
 
     // Respond with some headers and all corresponding bodies
     final Responder fullResponder = RespondingEthPeer.blockchainResponder(blockchain);
@@ -116,12 +117,14 @@ public class ImportBlocksTaskTest
     final RespondingEthPeer peer = EthProtocolManagerTestUtil.createPeer(ethProtocolManager);
 
     // Execute task
-    final AtomicReference<List<Block>> actualResult = new AtomicReference<>();
+    final AtomicReference<List<Hash>> actualResult = new AtomicReference<>();
     final AtomicReference<EthPeer> actualPeer = new AtomicReference<>();
     final AtomicBoolean done = new AtomicBoolean(false);
     final List<Block> requestedData = generateDataToBeRequested();
-    final EthTask<PeerTaskResult<List<Block>>> task = createTask(requestedData);
-    final CompletableFuture<PeerTaskResult<List<Block>>> future = task.run();
+    final List<Hash> requestedHashes =
+        requestedData.stream().map(Block::getHash).collect(Collectors.toList());
+    final EthTask<PeerTaskResult<List<Hash>>> task = createTask(requestedData);
+    final CompletableFuture<PeerTaskResult<List<Hash>>> future = task.run();
     future.whenComplete(
         (response, error) -> {
           actualResult.set(response.getResult());
@@ -135,15 +138,14 @@ public class ImportBlocksTaskTest
     assertThat(done).isTrue();
     assertThat(actualPeer.get()).isEqualTo(peer.getEthPeer());
     assertThat(actualResult.get().size()).isLessThan(requestedData.size());
-    for (final Block block : actualResult.get()) {
-      assertThat(requestedData).contains(block);
-      assertThat(blockchain.contains(block.getHash())).isTrue();
+    for (final Hash hash : actualResult.get()) {
+      assertThat(requestedHashes).contains(hash);
+      assertThat(blockchain.contains(hash)).isTrue();
     }
   }
 
   @Test
-  public void completesWhenPeersSendEmptyResponses()
-      throws ExecutionException, InterruptedException {
+  public void completesWhenPeersSendEmptyResponses() {
     // Setup a unresponsive peer
     final Responder responder = RespondingEthPeer.emptyResponder();
     final RespondingEthPeer respondingEthPeer =
@@ -152,13 +154,10 @@ public class ImportBlocksTaskTest
     // Execute task and wait for response
     final AtomicBoolean done = new AtomicBoolean(false);
     final List<Block> requestedData = generateDataToBeRequested();
-    final EthTask<PeerTaskResult<List<Block>>> task = createTask(requestedData);
-    final CompletableFuture<PeerTaskResult<List<Block>>> future = task.run();
+    final EthTask<PeerTaskResult<List<Hash>>> task = createTask(requestedData);
+    final CompletableFuture<PeerTaskResult<List<Hash>>> future = task.run();
     respondingEthPeer.respondWhile(responder, () -> !future.isDone());
-    future.whenComplete(
-        (response, error) -> {
-          done.compareAndSet(false, true);
-        });
+    future.whenComplete((response, error) -> done.compareAndSet(false, true));
     assertThat(future.isDone()).isTrue();
     assertThat(future.isCompletedExceptionally()).isFalse();
   }
@@ -172,8 +171,8 @@ public class ImportBlocksTaskTest
 
     // Execute task and wait for response
     final List<Block> requestedData = generateDataToBeRequested();
-    final EthTask<PeerTaskResult<List<Block>>> task = createTask(requestedData);
-    final CompletableFuture<PeerTaskResult<List<Block>>> future = task.run();
+    final EthTask<PeerTaskResult<List<Hash>>> task = createTask(requestedData);
+    final CompletableFuture<PeerTaskResult<List<Hash>>> future = task.run();
     respondingEthPeer.respondWhile(responder, () -> !future.isDone());
     assertThat(future.isDone()).isTrue();
     assertThat(future.isCompletedExceptionally()).isTrue();