commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
commit 8fc82b6e952b97efb25cf99434e5f6c2b50e95fe
Author: Danno Ferrin <danno.ferrin@gmail.com>
Date:   Sat Nov 30 18:53:01 2019 -0700

    NewBlockHeaders performance improvement (#230)
    
    * NewBlockHeaders performance improvement
    
    When sending out new block headers to the websocket subscribers we
    serialized the block once per each subscriber.  This had some crypto
    calls for each serialization and was CPU bound with redundant
    calculations.
    
    We can memoize the result and only serialize it once per block.
    
    Signed-off-by: Danno Ferrin <danno.ferrin@gmail.com>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
index bfb53f0f9..d5ebf35b6 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionService.java
@@ -24,6 +24,10 @@ import org.hyperledger.besu.ethereum.chain.BlockAddedObserver;
 import org.hyperledger.besu.ethereum.chain.Blockchain;
 import org.hyperledger.besu.ethereum.core.Hash;
 
+import java.util.function.Supplier;
+
+import com.google.common.base.Suppliers;
+
 public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
 
   private final SubscriptionManager subscriptionManager;
@@ -45,11 +49,15 @@ public class NewBlockHeadersSubscriptionService implements BlockAddedObserver {
           subscribers -> {
             final Hash newBlockHash = event.getBlock().getHash();
 
+            // memoize
+            final Supplier<BlockResult> blockWithTx =
+                Suppliers.memoize(() -> blockWithCompleteTransaction(newBlockHash));
+            final Supplier<BlockResult> blockWithoutTx =
+                Suppliers.memoize(() -> blockWithTransactionHash(newBlockHash));
+
             for (final NewBlockHeadersSubscription subscription : subscribers) {
               final BlockResult newBlock =
-                  subscription.getIncludeTransactions()
-                      ? blockWithCompleteTransaction(newBlockHash)
-                      : blockWithTransactionHash(newBlockHash);
+                  subscription.getIncludeTransactions() ? blockWithTx.get() : blockWithoutTx.get();
 
               subscriptionManager.sendMessage(subscription.getSubscriptionId(), newBlock);
             }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
index 681b8b50c..2c15aa621 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/subscription/blockheaders/NewBlockHeadersSubscriptionServiceTest.java
@@ -149,6 +149,29 @@ public class NewBlockHeadersSubscriptionServiceTest {
     verify(blockchainQueries, times(1)).blockByHash(any());
   }
 
+  @Test
+  public void shouldOnlyCreateResponsesOnce() {
+    final NewBlockHeadersSubscription subscription1 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription2 = createSubscription(false);
+    final NewBlockHeadersSubscription subscription3 = createSubscription(true);
+    final NewBlockHeadersSubscription subscription4 = createSubscription(false);
+    mockSubscriptionManagerNotifyMethod(subscription1, subscription2, subscription3, subscription4);
+
+    simulateAddingBlockOnCanonicalChain();
+
+    verify(subscriptionManager, times(4))
+        .sendMessage(subscriptionIdCaptor.capture(), responseCaptor.capture());
+    assertThat(subscriptionIdCaptor.getAllValues())
+        .containsExactly(
+            subscription1.getSubscriptionId(),
+            subscription2.getSubscriptionId(),
+            subscription3.getSubscriptionId(),
+            subscription4.getSubscriptionId());
+
+    verify(blockchainQueries, times(1)).blockByHashWithTxHashes(any());
+    verify(blockchainQueries, times(1)).blockByHash(any());
+  }
+
   private BlockResult expectedBlockWithTransactions(final List<Hash> objects) {
     final BlockWithMetadata<Hash, Hash> testBlockWithMetadata =
         new BlockWithMetadata<>(blockHeader, objects, Collections.emptyList(), UInt256.ONE, 1);
@@ -159,11 +182,12 @@ public class NewBlockHeadersSubscriptionServiceTest {
     return expectedNewBlock;
   }
 
-  private void mockSubscriptionManagerNotifyMethod(final NewBlockHeadersSubscription subscription) {
+  private void mockSubscriptionManagerNotifyMethod(
+      final NewBlockHeadersSubscription... subscriptions) {
     doAnswer(
             invocation -> {
               Consumer<List<NewBlockHeadersSubscription>> consumer = invocation.getArgument(2);
-              consumer.accept(Collections.singletonList(subscription));
+              consumer.accept(List.of(subscriptions));
               return null;
             })
         .when(subscriptionManager)
