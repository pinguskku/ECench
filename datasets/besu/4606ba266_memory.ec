commit 4606ba2661ed65431f78bdcc5b6ca240ef2ce1a6
Author: mbaxter <mbaxter@users.noreply.github.com>
Date:   Wed May 1 15:59:38 2019 -0400

    Remove unnecessary field (#1384)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProvider.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProvider.java
index c6d02f3d6..85d736bfc 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProvider.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProvider.java
@@ -21,14 +21,12 @@ import tech.pegasys.pantheon.util.enode.EnodeURL;
 
 import java.util.Collection;
 import java.util.Optional;
-import java.util.function.Supplier;
 
 /**
  * A permissioning provider that only provides an answer when we have no peers outside of our
  * bootnodes
  */
 public class InsufficientPeersPermissioningProvider implements ContextualNodePermissioningProvider {
-  private final Supplier<Optional<EnodeURL>> selfEnode;
   private final P2PNetwork p2pNetwork;
   private final Collection<EnodeURL> bootnodeEnodes;
   private long nonBootnodePeerConnections;
@@ -38,15 +36,10 @@ public class InsufficientPeersPermissioningProvider implements ContextualNodePer
    * Creates the provider observing the provided p2p network
    *
    * @param p2pNetwork the p2p network to observe
-   * @param selfEnode A supplier that provides a representation of the locally running node, if
-   *     available
    * @param bootnodeEnodes the bootnodes that this node is configured to connection to
    */
   public InsufficientPeersPermissioningProvider(
-      final P2PNetwork p2pNetwork,
-      final Supplier<Optional<EnodeURL>> selfEnode,
-      final Collection<EnodeURL> bootnodeEnodes) {
-    this.selfEnode = selfEnode;
+      final P2PNetwork p2pNetwork, final Collection<EnodeURL> bootnodeEnodes) {
     this.p2pNetwork = p2pNetwork;
     this.bootnodeEnodes = bootnodeEnodes;
     this.nonBootnodePeerConnections = countP2PNetworkNonBootnodeConnections();
@@ -66,7 +59,7 @@ public class InsufficientPeersPermissioningProvider implements ContextualNodePer
   @Override
   public Optional<Boolean> isPermitted(
       final EnodeURL sourceEnode, final EnodeURL destinationEnode) {
-    Optional<EnodeURL> maybeSelfEnode = selfEnode.get();
+    Optional<EnodeURL> maybeSelfEnode = p2pNetwork.getLocalEnode();
     if (nonBootnodePeerConnections > 0) {
       return Optional.empty();
     } else if (!maybeSelfEnode.isPresent()) {
diff --git a/ethereum/p2p/src/test/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProviderTest.java b/ethereum/p2p/src/test/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProviderTest.java
index 0cced86e6..c8d4b886e 100644
--- a/ethereum/p2p/src/test/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProviderTest.java
+++ b/ethereum/p2p/src/test/java/tech/pegasys/pantheon/ethereum/p2p/InsufficientPeersPermissioningProviderTest.java
@@ -29,6 +29,7 @@ import java.util.Collections;
 import java.util.Optional;
 import java.util.function.Consumer;
 
+import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
 import org.mockito.ArgumentCaptor;
@@ -54,6 +55,11 @@ public class InsufficientPeersPermissioningProviderTest {
       EnodeURL.fromString(
           "enode://00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005@192.168.0.5:30303");
 
+  @Before
+  public void setup() {
+    when(p2pNetwork.getLocalEnode()).thenReturn(Optional.of(SELF_ENODE));
+  }
+
   @Test
   public void noResultWhenNoBootnodes() {
     final Collection<EnodeURL> bootnodes = Collections.emptyList();
@@ -61,8 +67,7 @@ public class InsufficientPeersPermissioningProviderTest {
     when(p2pNetwork.getPeers()).thenReturn(Collections.emptyList());
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_2)).isEmpty();
   }
@@ -76,8 +81,7 @@ public class InsufficientPeersPermissioningProviderTest {
     final Collection<EnodeURL> bootnodes = Collections.singletonList(ENODE_2);
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_3)).isEmpty();
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_2)).isEmpty();
@@ -90,8 +94,7 @@ public class InsufficientPeersPermissioningProviderTest {
     when(p2pNetwork.getPeers()).thenReturn(Collections.emptyList());
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_2)).contains(true);
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_3)).isEmpty();
@@ -102,9 +105,10 @@ public class InsufficientPeersPermissioningProviderTest {
     final Collection<EnodeURL> bootnodes = Collections.singletonList(ENODE_2);
 
     when(p2pNetwork.getPeers()).thenReturn(Collections.emptyList());
+    when(p2pNetwork.getLocalEnode()).thenReturn(Optional.empty());
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(p2pNetwork, Optional::empty, bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_2)).isEmpty();
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_3)).isEmpty();
@@ -119,8 +123,7 @@ public class InsufficientPeersPermissioningProviderTest {
     when(p2pNetwork.getPeers()).thenReturn(Collections.singletonList(bootnodeMatchPeerConnection));
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_2)).contains(true);
     assertThat(provider.isPermitted(SELF_ENODE, ENODE_3)).isEmpty();
@@ -143,8 +146,7 @@ public class InsufficientPeersPermissioningProviderTest {
     when(p2pNetwork.getPeers()).thenReturn(pcs);
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     final ArgumentCaptor<DisconnectCallback> callbackCaptor =
         ArgumentCaptor.forClass(DisconnectCallback.class);
@@ -171,8 +173,7 @@ public class InsufficientPeersPermissioningProviderTest {
     when(p2pNetwork.getPeers()).thenReturn(pcs);
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     @SuppressWarnings("unchecked")
     final ArgumentCaptor<Consumer<PeerConnection>> callbackCaptor =
@@ -205,8 +206,7 @@ public class InsufficientPeersPermissioningProviderTest {
     when(p2pNetwork.getPeers()).thenReturn(pcs);
 
     final InsufficientPeersPermissioningProvider provider =
-        new InsufficientPeersPermissioningProvider(
-            p2pNetwork, () -> Optional.of(SELF_ENODE), bootnodes);
+        new InsufficientPeersPermissioningProvider(p2pNetwork, bootnodes);
 
     @SuppressWarnings("unchecked")
     final ArgumentCaptor<Consumer<PeerConnection>> connectCallbackCaptor =
diff --git a/pantheon/src/main/java/tech/pegasys/pantheon/RunnerBuilder.java b/pantheon/src/main/java/tech/pegasys/pantheon/RunnerBuilder.java
index eb0de4def..7bcaf3d36 100644
--- a/pantheon/src/main/java/tech/pegasys/pantheon/RunnerBuilder.java
+++ b/pantheon/src/main/java/tech/pegasys/pantheon/RunnerBuilder.java
@@ -287,8 +287,7 @@ public class RunnerBuilder {
     nodePermissioningController.ifPresent(
         n ->
             n.setInsufficientPeersPermissioningProvider(
-                new InsufficientPeersPermissioningProvider(
-                    networkRunner.getNetwork(), network::getLocalEnode, bootnodesAsEnodeURLs)));
+                new InsufficientPeersPermissioningProvider(network, bootnodesAsEnodeURLs)));
 
     final TransactionPool transactionPool = pantheonController.getTransactionPool();
     final MiningCoordinator miningCoordinator = pantheonController.getMiningCoordinator();