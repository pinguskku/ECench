commit 463fc3994e5198f66debaa91c90f148e9d84716f
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Sat Feb 16 06:42:54 2019 +1000

    Introduce FutureUtils to reduce duplicated code around CompletableFuture (#868)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/AbstractEthTask.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/AbstractEthTask.java
index ad2dfc000..b88693553 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/AbstractEthTask.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/AbstractEthTask.java
@@ -12,6 +12,8 @@
  */
 package tech.pegasys.pantheon.ethereum.eth.manager;
 
+import static tech.pegasys.pantheon.util.FutureUtils.completedExceptionally;
+
 import tech.pegasys.pantheon.metrics.LabelledMetric;
 import tech.pegasys.pantheon.metrics.OperationTimer;
 
@@ -110,9 +112,7 @@ public abstract class AbstractEthTask<T> implements EthTask<T> {
             });
         return subTaskFuture;
       } else {
-        final CompletableFuture<S> future = new CompletableFuture<>();
-        future.completeExceptionally(new CancellationException());
-        return future;
+        return completedExceptionally(new CancellationException());
       }
     }
   }
@@ -135,9 +135,7 @@ public abstract class AbstractEthTask<T> implements EthTask<T> {
             });
         return subTaskFuture;
       } else {
-        final CompletableFuture<S> future = new CompletableFuture<>();
-        future.completeExceptionally(new CancellationException());
-        return future;
+        return completedExceptionally(new CancellationException());
       }
     }
   }
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthScheduler.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthScheduler.java
index 3e2eef700..9903ece9e 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthScheduler.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthScheduler.java
@@ -12,6 +12,8 @@
  */
 package tech.pegasys.pantheon.ethereum.eth.manager;
 
+import static tech.pegasys.pantheon.util.FutureUtils.propagateResult;
+
 import tech.pegasys.pantheon.util.ExceptionUtils;
 
 import java.time.Duration;
@@ -98,19 +100,7 @@ public class EthScheduler {
       final Supplier<CompletableFuture<T>> future) {
     final CompletableFuture<T> promise = new CompletableFuture<>();
     final Future<?> workerFuture =
-        syncWorkerExecutor.submit(
-            () -> {
-              future
-                  .get()
-                  .whenComplete(
-                      (r, t) -> {
-                        if (t != null) {
-                          promise.completeExceptionally(t);
-                        } else {
-                          promise.complete(r);
-                        }
-                      });
-            });
+        syncWorkerExecutor.submit(() -> propagateResult(future.get(), promise));
     // If returned promise is cancelled, cancel the worker future
     promise.whenComplete(
         (r, t) -> {
@@ -170,18 +160,7 @@ public class EthScheduler {
     final CompletableFuture<T> promise = new CompletableFuture<>();
     final ScheduledFuture<?> scheduledFuture =
         scheduler.schedule(
-            () -> {
-              future
-                  .get()
-                  .whenComplete(
-                      (r, t) -> {
-                        if (t != null) {
-                          promise.completeExceptionally(t);
-                        } else {
-                          promise.complete(r);
-                        }
-                      });
-            },
+            () -> propagateResult(future.get(), promise),
             duration.toMillis(),
             TimeUnit.MILLISECONDS);
     // If returned promise is cancelled, cancel scheduled task
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncActions.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncActions.java
index a6c37951f..2fa221a96 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncActions.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncActions.java
@@ -14,6 +14,8 @@ package tech.pegasys.pantheon.ethereum.eth.sync.fastsync;
 
 import static java.util.concurrent.CompletableFuture.completedFuture;
 import static tech.pegasys.pantheon.ethereum.eth.sync.fastsync.FastSyncError.CHAIN_TOO_SHORT;
+import static tech.pegasys.pantheon.util.FutureUtils.completedExceptionally;
+import static tech.pegasys.pantheon.util.FutureUtils.exceptionallyCompose;
 
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
@@ -73,59 +75,39 @@ public class FastSyncActions<C> {
             ethContext, syncConfig.getFastSyncMinimumPeerCount(), ethTasksTimer);
 
     final EthScheduler scheduler = ethContext.getScheduler();
-    final CompletableFuture<FastSyncState> result = new CompletableFuture<>();
-    scheduler
-        .timeout(waitForPeersTask, syncConfig.getFastSyncMaximumPeerWaitTime())
-        .handle(
-            (waitResult, error) -> {
+    return exceptionallyCompose(
+            scheduler.timeout(waitForPeersTask, syncConfig.getFastSyncMaximumPeerWaitTime()),
+            error -> {
               if (ExceptionUtils.rootCause(error) instanceof TimeoutException) {
                 if (ethContext.getEthPeers().availablePeerCount() > 0) {
                   LOG.warn(
                       "Fast sync timed out before minimum peer count was reached. Continuing with reduced peers.");
-                  result.complete(fastSyncState);
+                  return completedFuture(null);
                 } else {
                   LOG.warn(
                       "Maximum wait time for fast sync reached but no peers available. Continuing to wait for any available peer.");
-                  waitForAnyPeer()
-                      .thenAccept(value -> result.complete(fastSyncState))
-                      .exceptionally(
-                          taskError -> {
-                            result.completeExceptionally(error);
-                            return null;
-                          });
+                  return waitForAnyPeer();
                 }
               } else if (error != null) {
                 LOG.error("Failed to find peers for fast sync", error);
-                result.completeExceptionally(error);
-              } else {
-                result.complete(fastSyncState);
+                return completedExceptionally(error);
               }
               return null;
-            });
-
-    return result;
+            })
+        .thenApply(successfulWaitResult -> fastSyncState);
   }
 
   private CompletableFuture<Void> waitForAnyPeer() {
-    final CompletableFuture<Void> result = new CompletableFuture<>();
-    waitForAnyPeer(result);
-    return result;
-  }
-
-  private void waitForAnyPeer(final CompletableFuture<Void> result) {
-    ethContext
-        .getScheduler()
-        .timeout(WaitForPeersTask.create(ethContext, 1, ethTasksTimer))
-        .whenComplete(
-            (waitResult, throwable) -> {
-              if (ExceptionUtils.rootCause(throwable) instanceof TimeoutException) {
-                waitForAnyPeer(result);
-              } else if (throwable != null) {
-                result.completeExceptionally(throwable);
-              } else {
-                result.complete(waitResult);
-              }
-            });
+    final CompletableFuture<Void> waitForPeerResult =
+        ethContext.getScheduler().timeout(WaitForPeersTask.create(ethContext, 1, ethTasksTimer));
+    return exceptionallyCompose(
+        waitForPeerResult,
+        throwable -> {
+          if (ExceptionUtils.rootCause(throwable) instanceof TimeoutException) {
+            return waitForAnyPeer();
+          }
+          return completedExceptionally(throwable);
+        });
   }
 
   public CompletableFuture<FastSyncState> selectPivotBlock(final FastSyncState fastSyncState) {
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java
index decd2040e..ce9382a6a 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/fastsync/FastSyncBlockHandler.java
@@ -13,6 +13,7 @@
 package tech.pegasys.pantheon.ethereum.eth.sync.fastsync;
 
 import static java.util.Collections.emptyList;
+import static tech.pegasys.pantheon.util.FutureUtils.completedExceptionally;
 
 import tech.pegasys.pantheon.ethereum.ProtocolContext;
 import tech.pegasys.pantheon.ethereum.core.Block;
@@ -112,11 +113,9 @@ public class FastSyncBlockHandler<C> implements BlockHandler<BlockWithReceipts>
   }
 
   private CompletableFuture<List<BlockWithReceipts>> invalidBlockFailure(final Block block) {
-    final CompletableFuture<List<BlockWithReceipts>> result = new CompletableFuture<>();
-    result.completeExceptionally(
+    return completedExceptionally(
         new InvalidBlockException(
             "Failed to import block", block.getHeader().getNumber(), block.getHash()));
-    return result;
   }
 
   private BlockImporter<C> getBlockImporter(final BlockWithReceipts blockWithReceipt) {
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/GetBlockFromPeerTask.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/GetBlockFromPeerTask.java
index 13b1eff09..834c203fa 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/GetBlockFromPeerTask.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/sync/tasks/GetBlockFromPeerTask.java
@@ -12,6 +12,8 @@
  */
 package tech.pegasys.pantheon.ethereum.eth.sync.tasks;
 
+import static tech.pegasys.pantheon.util.FutureUtils.completedExceptionally;
+
 import tech.pegasys.pantheon.ethereum.core.Block;
 import tech.pegasys.pantheon.ethereum.core.BlockHeader;
 import tech.pegasys.pantheon.ethereum.core.Hash;
@@ -87,9 +89,7 @@ public class GetBlockFromPeerTask extends AbstractPeerTask<Block> {
   private CompletableFuture<PeerTaskResult<List<Block>>> completeBlock(
       final PeerTaskResult<List<BlockHeader>> headerResult) {
     if (headerResult.getResult().isEmpty()) {
-      final CompletableFuture<PeerTaskResult<List<Block>>> future = new CompletableFuture<>();
-      future.completeExceptionally(new IncompleteResultsException());
-      return future;
+      return completedExceptionally(new IncompleteResultsException());
     }
 
     return executeSubTask(
diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/discovery/PeerDiscoveryAgent.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/discovery/PeerDiscoveryAgent.java
index 32b720c4d..bd18cc0b5 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/discovery/PeerDiscoveryAgent.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/discovery/PeerDiscoveryAgent.java
@@ -121,13 +121,12 @@ public abstract class PeerDiscoveryAgent implements DisconnectCallback {
   public abstract CompletableFuture<?> stop();
 
   public CompletableFuture<?> start() {
-    final CompletableFuture<?> future = new CompletableFuture<>();
     if (config.isActive()) {
       final String host = config.getBindHost();
       final int port = config.getBindPort();
       LOG.info("Starting peer discovery agent on host={}, port={}", host, port);
 
-      listenForConnections()
+      return listenForConnections()
           .thenAccept(
               (InetSocketAddress localAddress) -> {
                 // Once listener is set up, finish initializing
@@ -140,21 +139,11 @@ public abstract class PeerDiscoveryAgent implements DisconnectCallback {
                         localAddress.getPort());
                 isActive = true;
                 startController();
-              })
-          .whenComplete(
-              (res, err) -> {
-                // Finalize future
-                if (err != null) {
-                  future.completeExceptionally(err);
-                } else {
-                  future.complete(null);
-                }
               });
     } else {
       this.isActive = false;
-      future.complete(null);
+      return CompletableFuture.completedFuture(null);
     }
-    return future;
   }
 
   private void startController() {
diff --git a/util/src/main/java/tech/pegasys/pantheon/util/FutureUtils.java b/util/src/main/java/tech/pegasys/pantheon/util/FutureUtils.java
new file mode 100644
index 000000000..fd1aa7962
--- /dev/null
+++ b/util/src/main/java/tech/pegasys/pantheon/util/FutureUtils.java
@@ -0,0 +1,87 @@
+/*
+ * Copyright 2019 ConsenSys AG.
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ */
+package tech.pegasys.pantheon.util;
+
+import static java.util.concurrent.CompletableFuture.completedFuture;
+
+import java.util.concurrent.CompletableFuture;
+import java.util.concurrent.CompletionStage;
+import java.util.function.Function;
+
+public class FutureUtils {
+
+  /**
+   * Creates a {@link CompletableFuture} that is exceptionally completed by <code>error</code>.
+   *
+   * @param error the error to exceptionally complete the future with
+   * @param <T> the type of CompletableFuture
+   * @return a CompletableFuture exceptionally completed by <code>error</code>.
+   */
+  public static <T> CompletableFuture<T> completedExceptionally(final Throwable error) {
+    final CompletableFuture<T> future = new CompletableFuture<>();
+    future.completeExceptionally(error);
+    return future;
+  }
+
+  /**
+   * Returns a new CompletionStage that, when the provided stage completes exceptionally, is
+   * executed with the provided stage's exception as the argument to the supplied function.
+   * Otherwise the returned stage completes successfully with the same value as the provided stage.
+   *
+   * <p>This is the exceptional equivalent to {@link CompletionStage#thenCompose(Function)}
+   *
+   * @param future the future to handle results or exceptions from
+   * @param errorHandler the function returning a new CompletionStage
+   * @param <T> the type of the CompletionStage's result
+   * @return the CompletionStage
+   */
+  public static <T> CompletableFuture<T> exceptionallyCompose(
+      final CompletableFuture<T> future,
+      final Function<Throwable, CompletionStage<T>> errorHandler) {
+    final CompletableFuture<T> result = new CompletableFuture<>();
+    future.whenComplete(
+        (value, error) -> {
+          try {
+            final CompletionStage<T> nextStep =
+                error != null ? errorHandler.apply(error) : completedFuture(value);
+            propagateResult(nextStep, result);
+          } catch (final Throwable t) {
+            result.completeExceptionally(t);
+          }
+        });
+    return result;
+  }
+
+  /**
+   * Propagates the result of one {@link CompletionStage} to a different {@link CompletableFuture}.
+   *
+   * <p>When <code>from</code> completes successfully, <code>to</code> will be completed
+   * successfully with the same value. When <code>from</code> completes exceptionally, <code>to
+   * </code> will be completed exceptionally with the same exception.
+   *
+   * @param from the CompletionStage to take results and exceptions from
+   * @param to the CompletableFuture to propagate results and exceptions to
+   * @param <T> the type of the success value
+   */
+  public static <T> void propagateResult(
+      final CompletionStage<T> from, final CompletableFuture<T> to) {
+    from.whenComplete(
+        (value, error) -> {
+          if (error != null) {
+            to.completeExceptionally(error);
+          } else {
+            to.complete(value);
+          }
+        });
+  }
+}
diff --git a/util/src/test/java/tech/pegasys/pantheon/util/FutureUtilsTest.java b/util/src/test/java/tech/pegasys/pantheon/util/FutureUtilsTest.java
new file mode 100644
index 000000000..6b3a56415
--- /dev/null
+++ b/util/src/test/java/tech/pegasys/pantheon/util/FutureUtilsTest.java
@@ -0,0 +1,169 @@
+/*
+ * Copyright 2019 ConsenSys AG.
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ */
+package tech.pegasys.pantheon.util;
+
+import static org.assertj.core.api.Assertions.assertThat;
+import static org.assertj.core.api.Assertions.assertThatThrownBy;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.verifyZeroInteractions;
+import static org.mockito.Mockito.when;
+import static tech.pegasys.pantheon.util.FutureUtils.exceptionallyCompose;
+import static tech.pegasys.pantheon.util.FutureUtils.propagateResult;
+
+import java.util.concurrent.CompletableFuture;
+import java.util.concurrent.CompletionStage;
+import java.util.concurrent.ExecutionException;
+import java.util.function.Function;
+
+import org.junit.Test;
+
+public class FutureUtilsTest {
+
+  private static final RuntimeException ERROR = new RuntimeException("Oh no!");
+
+  @Test
+  public void shouldCreateExceptionallyCompletedFuture() {
+    final CompletableFuture<Void> future = FutureUtils.completedExceptionally(ERROR);
+    assertCompletedExceptionally(future, ERROR);
+  }
+
+  @Test
+  public void shouldPropagateSuccessfulResult() {
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final CompletableFuture<String> output = new CompletableFuture<>();
+    propagateResult(input, output);
+    assertThat(output).isNotDone();
+
+    input.complete("Yay");
+
+    assertThat(output).isCompletedWithValue("Yay");
+  }
+
+  @Test
+  public void shouldPropagateSuccessfulNullResult() {
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final CompletableFuture<String> output = new CompletableFuture<>();
+    propagateResult(input, output);
+    assertThat(output).isNotDone();
+
+    input.complete(null);
+
+    assertThat(output).isCompletedWithValue(null);
+  }
+
+  @Test
+  public void shouldPropagateExceptionalResult() {
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final CompletableFuture<String> output = new CompletableFuture<>();
+    propagateResult(input, output);
+    assertThat(output).isNotDone();
+
+    input.completeExceptionally(ERROR);
+
+    assertCompletedExceptionally(output, ERROR);
+  }
+
+  @Test
+  public void shouldComposeExceptionallyWhenErrorOccurs() {
+    final Function<Throwable, CompletionStage<String>> errorHandler = mockFunction();
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final CompletableFuture<String> afterException = new CompletableFuture<>();
+    when(errorHandler.apply(ERROR)).thenReturn(afterException);
+
+    final CompletableFuture<String> result = exceptionallyCompose(input, errorHandler);
+
+    verifyZeroInteractions(errorHandler);
+    assertThat(result).isNotDone();
+
+    // Completing input should trigger our error handler but not complete the result yet.
+    input.completeExceptionally(ERROR);
+    verify(errorHandler).apply(ERROR);
+    assertThat(result).isNotDone();
+
+    afterException.complete("Done");
+    assertThat(result).isCompletedWithValue("Done");
+  }
+
+  @Test
+  public void shouldComposeExceptionallyWhenErrorOccursAndComposedFutureFails() {
+    final RuntimeException secondError = new RuntimeException("Again?");
+    final Function<Throwable, CompletionStage<String>> errorHandler = mockFunction();
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final CompletableFuture<String> afterException = new CompletableFuture<>();
+    when(errorHandler.apply(ERROR)).thenReturn(afterException);
+
+    final CompletableFuture<String> result = exceptionallyCompose(input, errorHandler);
+
+    verifyZeroInteractions(errorHandler);
+    assertThat(result).isNotDone();
+
+    // Completing input should trigger our error handler but not complete the result yet.
+    input.completeExceptionally(ERROR);
+    verify(errorHandler).apply(ERROR);
+    assertThat(result).isNotDone();
+
+    afterException.completeExceptionally(secondError);
+    assertCompletedExceptionally(result, secondError);
+  }
+
+  @Test
+  public void shouldComposeExceptionallyWhenErrorOccursAndErrorHandlerThrowsException() {
+    final Function<Throwable, CompletionStage<String>> errorHandler = mockFunction();
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final IllegalStateException thrownException = new IllegalStateException("Oops");
+    when(errorHandler.apply(ERROR)).thenThrow(thrownException);
+
+    final CompletableFuture<String> result = exceptionallyCompose(input, errorHandler);
+
+    verifyZeroInteractions(errorHandler);
+    assertThat(result).isNotDone();
+
+    // Completing input should trigger our error handler but not complete the result yet.
+    input.completeExceptionally(ERROR);
+    verify(errorHandler).apply(ERROR);
+
+    assertCompletedExceptionally(result, thrownException);
+  }
+
+  @Test
+  public void shouldNotCallErrorHandlerWhenFutureCompletesSuccessfully() {
+    final Function<Throwable, CompletionStage<String>> errorHandler = mockFunction();
+    final CompletableFuture<String> input = new CompletableFuture<>();
+    final CompletableFuture<String> afterException = new CompletableFuture<>();
+    when(errorHandler.apply(ERROR)).thenReturn(afterException);
+
+    final CompletableFuture<String> result = exceptionallyCompose(input, errorHandler);
+
+    verifyZeroInteractions(errorHandler);
+    assertThat(result).isNotDone();
+
+    input.complete("Done");
+    verifyZeroInteractions(errorHandler);
+    assertThat(result).isCompletedWithValue("Done");
+  }
+
+  private void assertCompletedExceptionally(
+      final CompletableFuture<?> future, final RuntimeException expectedError) {
+    assertThat(future).isCompletedExceptionally();
+    assertThatThrownBy(future::get)
+        .isInstanceOf(ExecutionException.class)
+        .extracting(Throwable::getCause)
+        .isSameAs(expectedError);
+  }
+
+  @SuppressWarnings("unchecked")
+  private <I, O> Function<I, O> mockFunction() {
+    return mock(Function.class);
+  }
+}