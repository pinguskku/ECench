commit c0ab50001b03377d12b7c19cf6e1176473ab7b8b
Author: David Mechler <david.mechler@consensys.net>
Date:   Mon Nov 23 08:18:39 2020 -0500

    Cleanup unnecessary logic around world state (#1591)
    
    * #1408 - Code cleanup; update to use Immutables
    
    Signed-off-by: David Mechler <david.mechler@consensys.net>

diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHash.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHash.java
index 490e974ec..046371721 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHash.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHash.java
@@ -17,24 +17,24 @@ package org.hyperledger.besu.ethereum.api.jsonrpc.internal.methods;
 
 import org.hyperledger.besu.ethereum.api.jsonrpc.RpcMethod;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequestContext;
-import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcError;
-import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcErrorResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.results.ImmutableMinerDataResult;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.results.ImmutableUncleRewardResult;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.results.MinerDataResult;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.results.MinerDataResult.UncleRewardResult;
 import org.hyperledger.besu.ethereum.api.query.BlockWithMetadata;
 import org.hyperledger.besu.ethereum.api.query.BlockchainQueries;
 import org.hyperledger.besu.ethereum.api.query.TransactionReceiptWithMetadata;
 import org.hyperledger.besu.ethereum.api.query.TransactionWithMetadata;
-import org.hyperledger.besu.ethereum.core.Address;
 import org.hyperledger.besu.ethereum.core.BlockHeader;
 import org.hyperledger.besu.ethereum.core.Hash;
 import org.hyperledger.besu.ethereum.core.Wei;
 import org.hyperledger.besu.ethereum.mainnet.ProtocolSchedule;
 import org.hyperledger.besu.ethereum.mainnet.ProtocolSpec;
 
-import java.util.HashMap;
-import java.util.Map;
+import java.util.ArrayList;
+import java.util.List;
 import java.util.Optional;
 import java.util.function.Supplier;
 
@@ -70,14 +70,6 @@ public class EthGetMinerDataByBlockHash implements JsonRpcMethod {
 
     MinerDataResult minerDataResult = null;
     if (block != null) {
-      if (!blockchain
-          .get()
-          .getWorldStateArchive()
-          .isWorldStateAvailable(block.getHeader().getStateRoot())) {
-        return new JsonRpcErrorResponse(
-            requestContext.getRequest().getId(), JsonRpcError.WORLD_STATE_UNAVAILABLE);
-      }
-
       minerDataResult = createMinerDataResult(block, protocolSchedule, blockchain.get());
     }
 
@@ -109,7 +101,7 @@ public class EthGetMinerDataByBlockHash implements JsonRpcMethod {
     final Wei uncleInclusionReward =
         staticBlockReward.multiply(block.getOmmers().size()).divide(32);
     final Wei netBlockReward = staticBlockReward.add(transactionFee).add(uncleInclusionReward);
-    final Map<Hash, Address> uncleRewards = new HashMap<>();
+    final List<UncleRewardResult> uncleRewards = new ArrayList<>();
     blockchainQueries
         .getBlockchain()
         .getBlockByNumber(block.getHeader().getNumber())
@@ -118,17 +110,24 @@ public class EthGetMinerDataByBlockHash implements JsonRpcMethod {
                 blockBody
                     .getBody()
                     .getOmmers()
-                    .forEach(header -> uncleRewards.put(header.getHash(), header.getCoinbase())));
+                    .forEach(
+                        header ->
+                            uncleRewards.add(
+                                ImmutableUncleRewardResult.builder()
+                                    .hash(header.getHash().toHexString())
+                                    .coinbase(header.getCoinbase().toHexString())
+                                    .build())));
 
-    return new MinerDataResult(
-        netBlockReward,
-        staticBlockReward,
-        transactionFee,
-        uncleInclusionReward,
-        uncleRewards,
-        blockHeader.getCoinbase(),
-        blockHeader.getExtraData(),
-        blockHeader.getDifficulty(),
-        block.getTotalDifficulty());
+    return ImmutableMinerDataResult.builder()
+        .netBlockReward(netBlockReward.toHexString())
+        .staticBlockReward(staticBlockReward.toHexString())
+        .transactionFee(transactionFee.toHexString())
+        .uncleInclusionReward(uncleInclusionReward.toHexString())
+        .uncleRewards(uncleRewards)
+        .coinbase(blockHeader.getCoinbase().toHexString())
+        .extraData(blockHeader.getExtraData().toHexString())
+        .difficulty(blockHeader.getDifficulty().toHexString())
+        .totalDifficulty(block.getTotalDifficulty().toHexString())
+        .build();
   }
 }
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumber.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumber.java
index b747bff91..d44125bb7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumber.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumber.java
@@ -18,8 +18,6 @@ package org.hyperledger.besu.ethereum.api.jsonrpc.internal.methods;
 import org.hyperledger.besu.ethereum.api.jsonrpc.RpcMethod;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequestContext;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.parameters.BlockParameter;
-import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcError;
-import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcErrorResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.results.MinerDataResult;
 import org.hyperledger.besu.ethereum.api.query.BlockWithMetadata;
 import org.hyperledger.besu.ethereum.api.query.BlockchainQueries;
@@ -54,13 +52,6 @@ public class EthGetMinerDataByBlockNumber extends AbstractBlockParameterMethod {
 
     MinerDataResult minerDataResult = null;
     if (block != null) {
-      if (!getBlockchainQueries()
-          .getWorldStateArchive()
-          .isWorldStateAvailable(block.getHeader().getStateRoot())) {
-        return new JsonRpcErrorResponse(
-            request.getRequest().getId(), JsonRpcError.WORLD_STATE_UNAVAILABLE);
-      }
-
       minerDataResult =
           EthGetMinerDataByBlockHash.createMinerDataResult(
               block, protocolSchedule, getBlockchainQueries());
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/results/MinerDataResult.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/results/MinerDataResult.java
index c851199f0..caae05897 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/results/MinerDataResult.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/results/MinerDataResult.java
@@ -14,106 +14,34 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.internal.results;
 
-import org.hyperledger.besu.ethereum.core.Address;
-import org.hyperledger.besu.ethereum.core.Difficulty;
-import org.hyperledger.besu.ethereum.core.Hash;
-import org.hyperledger.besu.ethereum.core.Wei;
-
 import java.util.List;
-import java.util.Map;
-import java.util.stream.Collectors;
 
-import org.apache.tuweni.bytes.Bytes;
+import org.immutables.value.Value;
 
-public class MinerDataResult implements JsonRpcResult {
-  private final String netBlockReward;
-  private final String staticBlockReward;
-  private final String transactionFee;
-  private final String uncleInclusionReward;
-  private final List<UncleRewardResult> uncleRewards;
-  private final String coinbase;
-  private final String extraData;
-  private final String difficulty;
-  private final String totalDifficulty;
+@Value.Immutable
+public abstract class MinerDataResult implements JsonRpcResult {
+  abstract String getNetBlockReward();
 
-  public MinerDataResult(
-      final Wei netBlockReward,
-      final Wei staticBlockReward,
-      final Wei transactionFee,
-      final Wei uncleInclusionReward,
-      final Map<Hash, Address> uncleRewards,
-      final Address coinbase,
-      final Bytes extraData,
-      final Difficulty difficulty,
-      final Difficulty totalDifficulty) {
-    this.netBlockReward = Quantity.create(netBlockReward);
-    this.staticBlockReward = Quantity.create(staticBlockReward);
-    this.transactionFee = Quantity.create(transactionFee);
-    this.uncleInclusionReward = Quantity.create(uncleInclusionReward);
-    this.uncleRewards = setUncleRewards(uncleRewards);
-    this.coinbase = coinbase.toString();
-    this.extraData = extraData.toString();
-    this.difficulty = Quantity.create(difficulty);
-    this.totalDifficulty = Quantity.create(totalDifficulty);
-  }
+  abstract String getStaticBlockReward();
 
-  public String getNetBlockReward() {
-    return netBlockReward;
-  }
+  abstract String getTransactionFee();
 
-  public String getStaticBlockReward() {
-    return staticBlockReward;
-  }
+  abstract String getUncleInclusionReward();
 
-  public String getTransactionFee() {
-    return transactionFee;
-  }
+  abstract List<UncleRewardResult> getUncleRewards();
 
-  public String getUncleInclusionReward() {
-    return uncleInclusionReward;
-  }
-
-  public List<UncleRewardResult> getUncleRewards() {
-    return uncleRewards;
-  }
+  abstract String getCoinbase();
 
-  public String getCoinbase() {
-    return coinbase;
-  }
-
-  public String getExtraData() {
-    return extraData;
-  }
-
-  public String getDifficulty() {
-    return difficulty;
-  }
-
-  public String getTotalDifficulty() {
-    return totalDifficulty;
-  }
-
-  private List<UncleRewardResult> setUncleRewards(final Map<Hash, Address> uncleRewards) {
-    return uncleRewards.entrySet().stream()
-        .map(b -> new UncleRewardResult(b.getKey().toString(), b.getValue().toString()))
-        .collect(Collectors.toList());
-  }
+  abstract String getExtraData();
 
-  private static class UncleRewardResult {
-    private final String hash;
-    private final String coinbase;
+  abstract String getDifficulty();
 
-    private UncleRewardResult(final String hash, final String coinbase) {
-      this.hash = hash;
-      this.coinbase = coinbase;
-    }
+  abstract String getTotalDifficulty();
 
-    public String getHash() {
-      return hash;
-    }
+  @Value.Immutable
+  public interface UncleRewardResult {
+    String getHash();
 
-    public String getCoinbase() {
-      return coinbase;
-    }
+    String getCoinbase();
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHashTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHashTest.java
index 8145fb0d9..7355925ac 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHashTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockHashTest.java
@@ -17,7 +17,6 @@ package org.hyperledger.besu.ethereum.api.jsonrpc.internal.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
 import static org.assertj.core.api.Assertions.assertThatThrownBy;
-import static org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcError.WORLD_STATE_UNAVAILABLE;
 import static org.mockito.ArgumentMatchers.any;
 import static org.mockito.Mockito.verifyNoMoreInteractions;
 import static org.mockito.Mockito.when;
@@ -25,7 +24,6 @@ import static org.mockito.Mockito.when;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequestContext;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.exception.InvalidJsonRpcParameters;
-import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcErrorResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.query.BlockWithMetadata;
@@ -39,7 +37,6 @@ import org.hyperledger.besu.ethereum.core.Hash;
 import org.hyperledger.besu.ethereum.core.Wei;
 import org.hyperledger.besu.ethereum.mainnet.ProtocolSchedule;
 import org.hyperledger.besu.ethereum.mainnet.ProtocolSpec;
-import org.hyperledger.besu.ethereum.worldstate.WorldStateArchive;
 
 import java.util.Collections;
 import java.util.Optional;
@@ -56,7 +53,6 @@ import org.mockito.junit.MockitoJUnitRunner;
 public class EthGetMinerDataByBlockHashTest {
   @Mock private BlockchainQueries blockchainQueries;
   @Mock private ProtocolSchedule protocolSchedule;
-  @Mock private WorldStateArchive worldStateArchive;
   @Mock private ProtocolSpec protocolSpec;
   @Mock private Blockchain blockChain;
   private EthGetMinerDataByBlockHash method;
@@ -82,8 +78,6 @@ public class EthGetMinerDataByBlockHashTest {
             header, Collections.emptyList(), Collections.emptyList(), Difficulty.of(100L), 5);
 
     when(blockchainQueries.blockByHash(any())).thenReturn(Optional.of(blockWithMetadata));
-    when(blockchainQueries.getWorldStateArchive()).thenReturn(worldStateArchive);
-    when(blockchainQueries.getWorldStateArchive().isWorldStateAvailable(any())).thenReturn(true);
     when(protocolSchedule.getByBlockNumber(header.getNumber())).thenReturn(protocolSpec);
     when(protocolSpec.getBlockReward()).thenReturn(Wei.fromEth(2));
     when(blockchainQueries.getBlockchain()).thenReturn(blockChain);
@@ -110,30 +104,6 @@ public class EthGetMinerDataByBlockHashTest {
         .hasFieldOrProperty("totalDifficulty");
   }
 
-  @Test
-  public void worldStateMissingTest() {
-    final BlockHeader header = blockHeaderTestFixture.buildHeader();
-    final BlockWithMetadata<TransactionWithMetadata, Hash> blockWithMetadata =
-        new BlockWithMetadata<>(
-            header, Collections.emptyList(), Collections.emptyList(), Difficulty.of(100L), 5);
-
-    when(blockchainQueries.blockByHash(any())).thenReturn(Optional.of(blockWithMetadata));
-    when(blockchainQueries.getWorldStateArchive()).thenReturn(worldStateArchive);
-    when(blockchainQueries.getWorldStateArchive().isWorldStateAvailable(any())).thenReturn(false);
-
-    JsonRpcRequest request =
-        new JsonRpcRequest(
-            "2.0",
-            ETH_METHOD,
-            Arrays.array("0x1349e5d4002e72615ae371dc173ba530bf98a7bef886d5b3b00ca5f217565039"));
-    JsonRpcRequestContext requestContext = new JsonRpcRequestContext(request);
-    JsonRpcResponse response = method.response(requestContext);
-
-    assertThat(response).isNotNull().isInstanceOf(JsonRpcErrorResponse.class);
-    assertThat(((JsonRpcErrorResponse) response).getError()).isNotNull();
-    assertThat(((JsonRpcErrorResponse) response).getError()).isEqualTo(WORLD_STATE_UNAVAILABLE);
-  }
-
   @Test
   public void exceptionWhenNoHashSuppliedTest() {
     JsonRpcRequest request = new JsonRpcRequest("2.0", ETH_METHOD, Arrays.array());
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumberTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumberTest.java
index efd0e70eb..e44cc001d 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumberTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/internal/methods/EthGetMinerDataByBlockNumberTest.java
@@ -17,8 +17,6 @@ package org.hyperledger.besu.ethereum.api.jsonrpc.internal.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
 import static org.assertj.core.api.Assertions.assertThatThrownBy;
-import static org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcError.WORLD_STATE_UNAVAILABLE;
-import static org.mockito.ArgumentMatchers.any;
 import static org.mockito.ArgumentMatchers.anyLong;
 import static org.mockito.Mockito.verifyNoMoreInteractions;
 import static org.mockito.Mockito.when;
@@ -26,7 +24,6 @@ import static org.mockito.Mockito.when;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequestContext;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.exception.InvalidJsonRpcParameters;
-import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcErrorResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.query.BlockWithMetadata;
@@ -40,7 +37,6 @@ import org.hyperledger.besu.ethereum.core.Hash;
 import org.hyperledger.besu.ethereum.core.Wei;
 import org.hyperledger.besu.ethereum.mainnet.ProtocolSchedule;
 import org.hyperledger.besu.ethereum.mainnet.ProtocolSpec;
-import org.hyperledger.besu.ethereum.worldstate.WorldStateArchive;
 
 import java.util.Collections;
 import java.util.Optional;
@@ -56,7 +52,6 @@ import org.mockito.junit.MockitoJUnitRunner;
 public class EthGetMinerDataByBlockNumberTest {
   @Mock private BlockchainQueries blockchainQueries;
   @Mock private ProtocolSchedule protocolSchedule;
-  @Mock private WorldStateArchive worldStateArchive;
   @Mock private ProtocolSpec protocolSpec;
   @Mock private Blockchain blockChain;
   private EthGetMinerDataByBlockNumber method;
@@ -81,8 +76,6 @@ public class EthGetMinerDataByBlockNumberTest {
             header, Collections.emptyList(), Collections.emptyList(), Difficulty.of(100L), 5);
 
     when(blockchainQueries.blockByNumber(anyLong())).thenReturn(Optional.of(blockWithMetadata));
-    when(blockchainQueries.getWorldStateArchive()).thenReturn(worldStateArchive);
-    when(blockchainQueries.getWorldStateArchive().isWorldStateAvailable(any())).thenReturn(true);
     when(protocolSchedule.getByBlockNumber(header.getNumber())).thenReturn(protocolSpec);
     when(protocolSpec.getBlockReward()).thenReturn(Wei.fromEth(2));
     when(blockchainQueries.getBlockchain()).thenReturn(blockChain);
@@ -105,26 +98,6 @@ public class EthGetMinerDataByBlockNumberTest {
         .hasFieldOrProperty("totalDifficulty");
   }
 
-  @Test
-  public void worldStateMissingTest() {
-    final BlockHeader header = blockHeaderTestFixture.buildHeader();
-    final BlockWithMetadata<TransactionWithMetadata, Hash> blockWithMetadata =
-        new BlockWithMetadata<>(
-            header, Collections.emptyList(), Collections.emptyList(), Difficulty.of(100L), 5);
-
-    when(blockchainQueries.blockByNumber(anyLong())).thenReturn(Optional.of(blockWithMetadata));
-    when(blockchainQueries.getWorldStateArchive()).thenReturn(worldStateArchive);
-    when(blockchainQueries.getWorldStateArchive().isWorldStateAvailable(any())).thenReturn(false);
-
-    JsonRpcRequest request = new JsonRpcRequest("2.0", ETH_METHOD, Arrays.array("5094833"));
-    JsonRpcRequestContext requestContext = new JsonRpcRequestContext(request);
-    JsonRpcResponse response = method.response(requestContext);
-
-    assertThat(response).isNotNull().isInstanceOf(JsonRpcErrorResponse.class);
-    assertThat(((JsonRpcErrorResponse) response).getError()).isNotNull();
-    assertThat(((JsonRpcErrorResponse) response).getError()).isEqualTo(WORLD_STATE_UNAVAILABLE);
-  }
-
   @Test
   public void exceptionWhenNoNumberSuppliedTest() {
     JsonRpcRequest request = new JsonRpcRequest("2.0", ETH_METHOD, Arrays.array());