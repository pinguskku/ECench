commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
commit 6b47c8fc4b4d09189c52a5698a82b6f13b7b978d
Author: fab-10 <91944855+fab-10@users.noreply.github.com>
Date:   Mon Jan 3 18:13:54 2022 +0100

    Stream JSON RPC responses to avoid creating big JSON strings in memory (#3076)
    
    * Stream JSON RPC responses to avoid creating big JSON string in memory for large responses
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Adapt code to last development on result with Optionals
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Log an error if there is an IOException during the streaming of the response
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Remove the intermediate String object creation, writing directly to a Buffer
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Implement response streaming for web socket
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix log messages
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Move inner classes to outer level, to avoid too big class files
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>
    
    * Fix copyright
    
    Signed-off-by: Fabio Di Fabio <fabio.difabio@consensys.net>

diff --git a/CHANGELOG.md b/CHANGELOG.md
index 00e454cf4..ac4f456c1 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -4,11 +4,10 @@
 
 ### Additions and Improvements
 - Re-order external services (e.g JsonRpcHttpService) to start before blocks start processing [#3118](https://github.com/hyperledger/besu/pull/3118)
+- Stream JSON RPC responses to avoid creating big JSON strings in memory [#3076] (https://github.com/hyperledger/besu/pull/3076)
 
 ### Bug Fixes
-- Update log4j to 2.16.0.
 - Make 'to' field optional in eth_call method according to the spec [#3177] (https://github.com/hyperledger/besu/pull/3177)
-- Update log4j to 2.17.0.
 
 ## 21.10.5
 
@@ -18,7 +17,7 @@
 ### Download Links
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.tar.gz \ SHA256 0d1b6ed8f3e1325ad0d4acabad63c192385e6dcbefe40dc6b647e8ad106445a8
 https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/21.10.5/besu-21.10.5.zip SHA256 \ a1689a8a65c4c6f633b686983a6a1653e7ac86e742ad2ec6351176482d6e0c57
- 
+
 ## 22.1.0-RC1
 
 ### 22.1.0-RC1 Breaking Changes
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
new file mode 100644
index 000000000..22d906909
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamer.java
@@ -0,0 +1,74 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+
+  private final HttpServerResponse response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean chunked = false;
+
+  public JsonResponseStreamer(final HttpServerResponse response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (!chunked) {
+      response.setChunked(true);
+      chunked = true;
+    }
+
+    if (response.writeQueueFull()) {
+      LOG.debug("HttpResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("HttpResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    response.write(buf);
+  }
+
+  @Override
+  public void close() throws IOException {
+    response.end();
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
index fedefe88d..081d9b0df 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonRpcHttpService.java
@@ -52,6 +52,7 @@ import org.hyperledger.besu.plugin.services.metrics.OperationTimer;
 import org.hyperledger.besu.util.ExceptionUtils;
 import org.hyperledger.besu.util.NetworkUtility;
 
+import java.io.IOException;
 import java.net.InetSocketAddress;
 import java.nio.file.Path;
 import java.util.List;
@@ -62,6 +63,9 @@ import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 import javax.annotation.Nullable;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
 import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
@@ -95,7 +99,6 @@ import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.PfxOptions;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.auth.User;
@@ -114,6 +117,11 @@ public class JsonRpcHttpService {
   private static final InetSocketAddress EMPTY_SOCKET_ADDRESS = new InetSocketAddress("0.0.0.0", 0);
   private static final String APPLICATION_JSON = "application/json";
   private static final JsonRpcResponse NO_RESPONSE = new JsonRpcNoResponse();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writerWithDefaultPrettyPrinter()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
   private static final String EMPTY_RESPONSE = "";
 
   private static final TextMapPropagator traceFormats =
@@ -230,10 +238,6 @@ public class JsonRpcHttpService {
     LOG.debug("max number of active connections {}", maxActiveConnections);
     this.tracer = GlobalOpenTelemetry.getTracer("org.hyperledger.besu.jsonrpc", "1.0.0");
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
     try {
       // Create the HTTP server and a router object.
@@ -616,8 +620,17 @@ public class JsonRpcHttpService {
 
             response
                 .setStatusCode(status(jsonRpcResponse).code())
-                .putHeader("Content-Type", APPLICATION_JSON)
-                .end(serialize(jsonRpcResponse));
+                .putHeader("Content-Type", APPLICATION_JSON);
+
+            if (jsonRpcResponse.getType() == JsonRpcResponseType.NONE) {
+              response.end(EMPTY_RESPONSE);
+            } else {
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), jsonRpcResponse);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
+            }
           }
         });
   }
@@ -646,15 +659,6 @@ public class JsonRpcHttpService {
     }
   }
 
-  private String serialize(final JsonRpcResponse response) {
-
-    if (response.getType() == JsonRpcResponseType.NONE) {
-      return EMPTY_RESPONSE;
-    }
-
-    return Json.encodePrettily(response);
-  }
-
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final RoutingContext routingContext, final JsonArray jsonArray, final Optional<User> user) {
@@ -690,7 +694,11 @@ public class JsonRpcHttpService {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              response.end(Json.encode(completed));
+              try {
+                JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(response), completed);
+              } catch (IOException ex) {
+                LOG.error("Error streaming JSON-RPC response", ex);
+              }
             });
   }
 
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
new file mode 100644
index 000000000..0c06256c6
--- /dev/null
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamer.java
@@ -0,0 +1,83 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import java.io.IOException;
+import java.io.OutputStream;
+import java.util.concurrent.Semaphore;
+
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.apache.logging.log4j.LogManager;
+import org.apache.logging.log4j.Logger;
+
+class JsonResponseStreamer extends OutputStream {
+
+  private static final Logger LOG = LogManager.getLogger();
+  private static final Buffer EMPTY_BUFFER = Buffer.buffer();
+
+  private final ServerWebSocket response;
+  private final Semaphore paused = new Semaphore(0);
+  private final byte[] singleByteBuf = new byte[1];
+  private boolean firstFrame = true;
+  private Buffer buffer = EMPTY_BUFFER;
+
+  public JsonResponseStreamer(final ServerWebSocket response) {
+    this.response = response;
+  }
+
+  @Override
+  public void write(final int b) throws IOException {
+    singleByteBuf[0] = (byte) b;
+    write(singleByteBuf, 0, 1);
+  }
+
+  @Override
+  public void write(final byte[] bbuf, final int off, final int len) throws IOException {
+    if (buffer != EMPTY_BUFFER) {
+      writeFrame(buffer, false);
+    }
+    Buffer buf = Buffer.buffer(len);
+    buf.appendBytes(bbuf, off, len);
+    buffer = buf;
+  }
+
+  private void writeFrame(final Buffer buf, final boolean isFinal) throws IOException {
+    if (response.writeQueueFull()) {
+      LOG.debug("WebSocketResponse write queue is full pausing streaming");
+      response.drainHandler(e -> paused.release());
+      try {
+        paused.acquire();
+        LOG.debug("WebSocketResponse write queue is not accepting more data, resuming streaming");
+      } catch (InterruptedException ex) {
+        Thread.currentThread().interrupt();
+        throw new IOException(
+            "Interrupted while waiting for HttpServerResponse to drain the write queue", ex);
+      }
+    }
+    if (firstFrame) {
+      response.writeFrame(WebSocketFrame.textFrame(buf.toString(), isFinal));
+      firstFrame = false;
+    } else {
+      response.writeFrame(WebSocketFrame.continuationFrame(buf, isFinal));
+    }
+  }
+
+  @Override
+  public void close() throws IOException {
+    writeFrame(buffer, true);
+  }
+}
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
index b4a67aece..12138550e 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandler.java
@@ -32,17 +32,22 @@ import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcUnauth
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods.WebSocketRpcRequest;
 import org.hyperledger.besu.ethereum.eth.manager.EthScheduler;
 
+import java.io.IOException;
 import java.util.List;
 import java.util.Map;
 import java.util.Optional;
 
+import com.fasterxml.jackson.core.JsonGenerator;
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.databind.ObjectWriter;
+import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import io.vertx.core.AsyncResult;
 import io.vertx.core.CompositeFuture;
 import io.vertx.core.Future;
 import io.vertx.core.Handler;
 import io.vertx.core.Promise;
 import io.vertx.core.Vertx;
-import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.ServerWebSocket;
 import io.vertx.core.json.DecodeException;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
@@ -54,6 +59,11 @@ import org.apache.logging.log4j.Logger;
 public class WebSocketRequestHandler {
 
   private static final Logger LOG = LogManager.getLogger();
+  private static final ObjectWriter JSON_OBJECT_WRITER =
+      new ObjectMapper()
+          .registerModule(new Jdk8Module()) // Handle JDK8 Optionals (de)serialization
+          .writer()
+          .without(JsonGenerator.Feature.FLUSH_PASSED_TO_STREAM);
 
   private final Vertx vertx;
   private final Map<String, JsonRpcMethod> methods;
@@ -71,29 +81,31 @@ public class WebSocketRequestHandler {
     this.timeoutSec = timeoutSec;
   }
 
-  public void handle(final String id, final String payload) {
-    handle(Optional.empty(), id, payload, Optional.empty());
+  public void handle(final ServerWebSocket websocket, final String payload) {
+    handle(Optional.empty(), websocket, payload, Optional.empty());
   }
 
   public void handle(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     vertx.executeBlocking(
-        executeHandler(authenticationService, id, payload, user), false, resultHandler(id));
+        executeHandler(authenticationService, websocket, payload, user),
+        false,
+        resultHandler(websocket));
   }
 
   private Handler<Promise<Object>> executeHandler(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final String payload,
       final Optional<User> user) {
     return future -> {
       final String json = payload.trim();
       if (!json.isEmpty() && json.charAt(0) == '{') {
         try {
-          handleSingleRequest(authenticationService, id, user, future, getRequest(payload));
+          handleSingleRequest(authenticationService, websocket, user, future, getRequest(payload));
         } catch (final IllegalArgumentException | DecodeException e) {
           LOG.debug("Error mapping json to WebSocketRpcRequest", e);
           future.complete(new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST));
@@ -110,14 +122,14 @@ public class WebSocketRequestHandler {
         }
         // handle batch request
         LOG.debug("batch request size {}", jsonArray.size());
-        handleJsonBatchRequest(authenticationService, id, jsonArray, user);
+        handleJsonBatchRequest(authenticationService, websocket, jsonArray, user);
       }
     };
   }
 
   private JsonRpcResponse process(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final WebSocketRpcRequest requestBody) {
 
@@ -128,7 +140,7 @@ public class WebSocketRequestHandler {
     final JsonRpcMethod method = methods.get(requestBody.getMethod());
     try {
       LOG.debug("WS-RPC request -> {}", requestBody.getMethod());
-      requestBody.setConnectionId(id);
+      requestBody.setConnectionId(websocket.textHandlerID());
       if (AuthenticationUtils.isPermitted(authenticationService, user, method)) {
         final JsonRpcRequestContext requestContext =
             new JsonRpcRequestContext(
@@ -151,17 +163,17 @@ public class WebSocketRequestHandler {
 
   private void handleSingleRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final Optional<User> user,
       final Promise<Object> future,
       final WebSocketRpcRequest requestBody) {
-    future.complete(process(authenticationService, id, user, requestBody));
+    future.complete(process(authenticationService, websocket, user, requestBody));
   }
 
   @SuppressWarnings("rawtypes")
   private void handleJsonBatchRequest(
       final Optional<AuthenticationService> authenticationService,
-      final String id,
+      final ServerWebSocket websocket,
       final JsonArray jsonArray,
       final Optional<User> user) {
     // Interpret json as rpc request
@@ -178,7 +190,10 @@ public class WebSocketRequestHandler {
                       future ->
                           future.complete(
                               process(
-                                  authenticationService, id, user, getRequest(req.toString()))));
+                                  authenticationService,
+                                  websocket,
+                                  user,
+                                  getRequest(req.toString()))));
                 })
             .collect(toList());
 
@@ -191,7 +206,7 @@ public class WebSocketRequestHandler {
                       .filter(this::isNonEmptyResponses)
                       .toArray(JsonRpcResponse[]::new);
 
-              vertx.eventBus().send(id, Json.encode(completed));
+              replyToClient(websocket, completed);
             });
   }
 
@@ -199,19 +214,22 @@ public class WebSocketRequestHandler {
     return Json.decodeValue(payload, WebSocketRpcRequest.class);
   }
 
-  private Handler<AsyncResult<Object>> resultHandler(final String id) {
+  private Handler<AsyncResult<Object>> resultHandler(final ServerWebSocket websocket) {
     return result -> {
       if (result.succeeded()) {
-        replyToClient(id, Json.encodeToBuffer(result.result()));
+        replyToClient(websocket, result.result());
       } else {
-        replyToClient(
-            id, Json.encodeToBuffer(new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR)));
+        replyToClient(websocket, new JsonRpcErrorResponse(null, JsonRpcError.INTERNAL_ERROR));
       }
     };
   }
 
-  private void replyToClient(final String id, final Buffer request) {
-    vertx.eventBus().send(id, request.toString());
+  private void replyToClient(final ServerWebSocket websocket, final Object result) {
+    try {
+      JSON_OBJECT_WRITER.writeValue(new JsonResponseStreamer(websocket), result);
+    } catch (IOException ex) {
+      LOG.error("Error streaming JSON-RPC response", ex);
+    }
   }
 
   private JsonRpcResponse errorResponse(final Object id, final JsonRpcError error) {
diff --git a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
index 2e7e856a1..907faf0c7 100644
--- a/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
+++ b/ethereum/api/src/main/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketService.java
@@ -25,7 +25,6 @@ import java.util.Optional;
 import java.util.concurrent.CompletableFuture;
 import java.util.concurrent.atomic.AtomicInteger;
 
-import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
 import com.google.common.annotations.VisibleForTesting;
 import com.google.common.base.Splitter;
 import com.google.common.collect.Iterables;
@@ -38,7 +37,6 @@ import io.vertx.core.http.HttpServerOptions;
 import io.vertx.core.http.HttpServerRequest;
 import io.vertx.core.http.HttpServerResponse;
 import io.vertx.core.http.ServerWebSocket;
-import io.vertx.core.json.jackson.DatabindCodec;
 import io.vertx.core.net.SocketAddress;
 import io.vertx.ext.web.Router;
 import io.vertx.ext.web.RoutingContext;
@@ -91,10 +89,6 @@ public class WebSocketService {
     LOG.info(
         "Starting Websocket service on {}:{}", configuration.getHost(), configuration.getPort());
 
-    // Handle JDK8 Optionals (de)serialization
-    DatabindCodec.mapper().registerModule(new Jdk8Module());
-    DatabindCodec.prettyMapper().registerModule(new Jdk8Module());
-
     final CompletableFuture<?> resultFuture = new CompletableFuture<>();
 
     httpServer =
@@ -141,7 +135,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, buffer.toString(), user));
+                        authenticationService, websocket, buffer.toString(), user));
           });
 
       websocket.textMessageHandler(
@@ -156,7 +150,7 @@ public class WebSocketService {
                 token,
                 user ->
                     websocketRequestHandler.handle(
-                        authenticationService, connectionId, payload, user));
+                        authenticationService, websocket, payload, user));
           });
 
       websocket.closeHandler(
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..08207ec00
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/JsonResponseStreamerTest.java
@@ -0,0 +1,120 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.buffer.Buffer;
+import io.vertx.core.http.HttpServerResponse;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write('x');
+
+    verify(httpResponse).write(argThat(bufferContains("x")));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+
+    verify(httpResponse).write(argThat(bufferContains("bcx")));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse);
+    streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    streamer.write('\n');
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("\n")));
+  }
+
+  @Test
+  public void writeStringAndClose() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).end();
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    HttpServerResponse httpResponse = mock(HttpServerResponse.class);
+    when(httpResponse.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(httpResponse.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(httpResponse)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(httpResponse).write(argThat(bufferContains("xyz")));
+    verify(httpResponse).write(argThat(bufferContains("123")));
+    verify(httpResponse).end();
+  }
+
+  private HttpServerResponse emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (HttpServerResponse) invocation.getMock();
+  }
+
+  private ArgumentMatcher<Buffer> bufferContains(final String text) {
+    return buf -> buf.toString().equals(text);
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
new file mode 100644
index 000000000..b62f8ac05
--- /dev/null
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/JsonResponseStreamerTest.java
@@ -0,0 +1,112 @@
+/*
+ * Copyright Hyperledger Besu contributors
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
+ * the License. You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
+ * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
+ * specific language governing permissions and limitations under the License.
+ *
+ * SPDX-License-Identifier: Apache-2.0
+ */
+package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
+
+import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
+
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.util.concurrent.Executors;
+import java.util.concurrent.TimeUnit;
+
+import io.vertx.core.Handler;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
+import org.junit.Test;
+import org.mockito.ArgumentMatcher;
+import org.mockito.invocation.InvocationOnMock;
+
+public class JsonResponseStreamerTest {
+
+  @Test
+  public void writeSingleChar() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write('x');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("x", true)));
+  }
+
+  @Test
+  public void writeString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8), 0, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", true)));
+  }
+
+  @Test
+  public void writeSubString() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("abcxyz".getBytes(StandardCharsets.UTF_8), 1, 3);
+    }
+
+    verify(response).writeFrame(argThat(frameContains("bcx", true)));
+  }
+
+  @Test
+  public void writeTwice() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write('\n');
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("\n", true)));
+  }
+
+  @Test
+  public void waitQueueIsDrained() throws IOException {
+    final ServerWebSocket response = mock(ServerWebSocket.class);
+
+    when(response.writeQueueFull()).thenReturn(Boolean.TRUE, Boolean.FALSE);
+
+    when(response.drainHandler(any())).then(this::emptyQueueAfterAWhile);
+
+    try (JsonResponseStreamer streamer = new JsonResponseStreamer(response)) {
+      streamer.write("xyz".getBytes(StandardCharsets.UTF_8));
+      streamer.write("123".getBytes(StandardCharsets.UTF_8));
+    }
+
+    verify(response).writeFrame(argThat(frameContains("xyz", false)));
+    verify(response).writeFrame(argThat(frameContains("123", true)));
+  }
+
+  private ServerWebSocket emptyQueueAfterAWhile(final InvocationOnMock invocation) {
+    Handler<Void> handler = invocation.getArgument(0);
+
+    Executors.newSingleThreadScheduledExecutor()
+        .schedule(() -> handler.handle(null), 1, TimeUnit.SECONDS);
+
+    return (ServerWebSocket) invocation.getMock();
+  }
+
+  private ArgumentMatcher<WebSocketFrame> frameContains(final String text, final boolean isFinal) {
+    return frame -> frame.textData().equals(text) && frame.isFinal() == isFinal;
+  }
+}
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
index e043f12a5..73045b2d8 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketRequestHandlerTest.java
@@ -14,6 +14,7 @@
  */
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket;
 
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
@@ -37,6 +38,8 @@ import java.util.Map;
 import java.util.UUID;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.core.json.JsonArray;
 import io.vertx.core.json.JsonObject;
@@ -47,7 +50,9 @@ import org.junit.After;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class WebSocketRequestHandlerTest {
@@ -57,6 +62,7 @@ public class WebSocketRequestHandlerTest {
   private Vertx vertx;
   private WebSocketRequestHandler handler;
   private JsonRpcMethod jsonRpcMethodMock;
+  private ServerWebSocket websocketMock;
   private final Map<String, JsonRpcMethod> methods = new HashMap<>();
 
   @Before
@@ -64,6 +70,9 @@ public class WebSocketRequestHandlerTest {
     vertx = Vertx.vertx();
 
     jsonRpcMethodMock = mock(JsonRpcMethod.class);
+    websocketMock = mock(ServerWebSocket.class);
+
+    when(websocketMock.textHandlerID()).thenReturn(UUID.randomUUID().toString());
 
     methods.put("eth_x", jsonRpcMethodMock);
     handler =
@@ -77,6 +86,7 @@ public class WebSocketRequestHandlerTest {
   @After
   public void after(final TestContext context) {
     Mockito.reset(jsonRpcMethodMock);
+    Mockito.reset(websocketMock);
     vertx.close(context.asyncAssertSuccess());
   }
 
@@ -93,20 +103,15 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock).response(eq(expectedRequest));
   }
 
@@ -126,20 +131,14 @@ public class WebSocketRequestHandlerTest {
 
     when(jsonRpcMethodMock.response(eq(expectedRequest))).thenReturn(expectedSingleResponse);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
     // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
     verify(jsonRpcMethodMock, Mockito.times(2)).response(eq(expectedRequest));
   }
 
@@ -160,19 +159,15 @@ public class WebSocketRequestHandlerTest {
     final JsonArray expectedBatchResponse =
         new JsonArray(List.of(expectedErrorResponse1, expectedErrorResponse2));
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedBatchResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, arrayJson.toString()));
+    handler.handle(websocketMock, arrayJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedBatchResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -182,20 +177,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, ""));
+    handler.handle(websocketMock, "");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -205,20 +196,16 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(null, JsonRpcError.INVALID_REQUEST);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              verifyNoInteractions(jsonRpcMethodMock);
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, "{}"));
+    handler.handle(websocketMock, "{}");
 
     async.awaitSuccess(VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+    verifyNoInteractions(jsonRpcMethodMock);
   }
 
   @Test
@@ -230,19 +217,14 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.METHOD_NOT_FOUND);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -258,19 +240,15 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INVALID_PARAMS);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -284,18 +262,29 @@ public class WebSocketRequestHandlerTest {
     final JsonRpcErrorResponse expectedResponse =
         new JsonRpcErrorResponse(1, JsonRpcError.INTERNAL_ERROR);
 
-    final String websocketId = UUID.randomUUID().toString();
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame))).then(completeOnLastFrame(async));
 
-    vertx
-        .eventBus()
-        .consumer(websocketId)
-        .handler(
-            msg -> {
-              context.assertEquals(Json.encode(expectedResponse), msg.body());
-              async.complete();
-            })
-        .completionHandler(v -> handler.handle(websocketId, requestJson.toString()));
+    handler.handle(websocketMock, requestJson.toString());
 
     async.awaitSuccess(WebSocketRequestHandlerTest.VERTX_AWAIT_TIMEOUT_MILLIS);
+
+    // can verify only after async not before
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
+  }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(final Async async) {
+    return invocation -> {
+      async.complete();
+      return websocketMock;
+    };
   }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
index 84e65111f..c2001b1e6 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/WebSocketServiceLoginTest.java
@@ -107,7 +107,6 @@ public class WebSocketServiceLoginTest {
         new HttpClientOptions()
             .setDefaultHost(websocketConfiguration.getHost())
             .setDefaultPort(websocketConfiguration.getPort());
-    ;
 
     httpClient = vertx.createHttpClient(httpClientOptions);
   }
@@ -223,9 +222,7 @@ public class WebSocketServiceLoginTest {
     options.setHost(websocketConfiguration.getHost());
     options.setPort(websocketConfiguration.getPort());
     String badtoken = "badtoken";
-    if (badtoken != null) {
-      options.addHeader("Authorization", "Bearer " + badtoken);
-    }
+    options.addHeader("Authorization", "Bearer " + badtoken);
     httpClient.webSocket(
         options,
         webSocket -> {
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
index df7c2c252..1dfe73a5b 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthSubscribeIntegrationTest.java
@@ -15,9 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
+import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.Subscription;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
@@ -29,17 +34,21 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 import java.util.List;
 import java.util.stream.Collectors;
+import java.util.stream.Stream;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
 import io.vertx.ext.unit.junit.VertxUnitRunner;
-import org.assertj.core.api.Assertions;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
 import org.mockito.Mockito;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthSubscribeIntegrationTest {
@@ -71,22 +80,23 @@ public class EthSubscribeIntegrationTest {
 
     final JsonRpcRequest subscribeRequestBody = createEthSubscribeRequestBody(CONNECTION_ID_1);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
-              assertThat(syncingSubscriptions).hasSize(1);
-              Assertions.assertThat(syncingSubscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID_1, Json.encode(subscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(subscribeRequestBody.getId(), "0x1");
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(subscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> syncingSubscriptions = getSubscriptions();
+    assertThat(syncingSubscriptions).hasSize(1);
+    assertThat(syncingSubscriptions.get(0).getConnectionId()).isEqualTo(CONNECTION_ID_1);
+    verify(websocketMock).writeFrame(argThat(isFrameWithAnyText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -96,43 +106,47 @@ public class EthSubscribeIntegrationTest {
     final JsonRpcRequest subscribeRequestBody1 = createEthSubscribeRequestBody(CONNECTION_ID_1);
     final JsonRpcRequest subscribeRequestBody2 = createEthSubscribeRequestBody(CONNECTION_ID_2);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID_1)
-        .handler(
-            msg -> {
-              final List<SyncingSubscription> subscriptions = getSubscriptions();
-              assertThat(subscriptions).hasSize(1);
-              Assertions.assertThat(subscriptions.get(0).getConnectionId())
-                  .isEqualTo(CONNECTION_ID_1);
-              async.countDown();
-
-              vertx
-                  .eventBus()
-                  .consumer(CONNECTION_ID_2)
-                  .handler(
-                      msg2 -> {
-                        final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
-                        assertThat(updatedSubscriptions).hasSize(2);
-                        final List<String> connectionIds =
-                            updatedSubscriptions.stream()
-                                .map(Subscription::getConnectionId)
-                                .collect(Collectors.toList());
-                        assertThat(connectionIds)
-                            .containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
-                        async.countDown();
-                      })
-                  .completionHandler(
-                      v ->
-                          webSocketRequestHandler.handle(
-                              CONNECTION_ID_2, Json.encode(subscribeRequestBody2)));
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(
-                    CONNECTION_ID_1, Json.encode(subscribeRequestBody1)));
+    final JsonRpcSuccessResponse expectedResponse1 =
+        new JsonRpcSuccessResponse(subscribeRequestBody1.getId(), "0x1");
+    final JsonRpcSuccessResponse expectedResponse2 =
+        new JsonRpcSuccessResponse(subscribeRequestBody2.getId(), "0x2");
+
+    final ServerWebSocket websocketMock1 = mock(ServerWebSocket.class);
+    when(websocketMock1.textHandlerID()).thenReturn(CONNECTION_ID_1);
+    when(websocketMock1.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock1));
+
+    final ServerWebSocket websocketMock2 = mock(ServerWebSocket.class);
+    when(websocketMock2.textHandlerID()).thenReturn(CONNECTION_ID_2);
+    when(websocketMock2.writeFrame(argThat(this::isFinalFrame)))
+        .then(countDownOnLastFrame(async, websocketMock2));
+
+    webSocketRequestHandler.handle(websocketMock1, Json.encode(subscribeRequestBody1));
+    webSocketRequestHandler.handle(websocketMock2, Json.encode(subscribeRequestBody2));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+
+    final List<SyncingSubscription> updatedSubscriptions = getSubscriptions();
+    assertThat(updatedSubscriptions).hasSize(2);
+    final List<String> connectionIds =
+        updatedSubscriptions.stream()
+            .map(Subscription::getConnectionId)
+            .collect(Collectors.toList());
+    assertThat(connectionIds).containsExactlyInAnyOrder(CONNECTION_ID_1, CONNECTION_ID_2);
+
+    verify(websocketMock1)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock1).writeFrame(argThat(this::isFinalFrame));
+
+    verify(websocketMock2)
+        .writeFrame(
+            argThat(
+                isFrameWithAnyText(
+                    Json.encode(expectedResponse1), Json.encode(expectedResponse2))));
+    verify(websocketMock2).writeFrame(argThat(this::isFinalFrame));
   }
 
   private List<SyncingSubscription> getSubscriptions() {
@@ -147,4 +161,28 @@ public class EthSubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithAnyText(final String... text) {
+    return f -> f.isText() && Stream.of(text).anyMatch(t -> t.equals(f.textData()));
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
+
+  private Answer<ServerWebSocket> countDownOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.countDown();
+      return websocket;
+    };
+  }
 }
diff --git a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
index db16e897e..2828ffdfd 100644
--- a/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
+++ b/ethereum/api/src/test/java/org/hyperledger/besu/ethereum/api/jsonrpc/websocket/methods/EthUnsubscribeIntegrationTest.java
@@ -15,10 +15,14 @@
 package org.hyperledger.besu.ethereum.api.jsonrpc.websocket.methods;
 
 import static org.assertj.core.api.Assertions.assertThat;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.Mockito.mock;
+import static org.mockito.Mockito.verify;
+import static org.mockito.Mockito.when;
 
 import org.hyperledger.besu.ethereum.api.handlers.TimeoutOptions;
 import org.hyperledger.besu.ethereum.api.jsonrpc.internal.JsonRpcRequest;
+import org.hyperledger.besu.ethereum.api.jsonrpc.internal.response.JsonRpcSuccessResponse;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.WebSocketRequestHandler;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.SubscriptionManager;
 import org.hyperledger.besu.ethereum.api.jsonrpc.websocket.subscription.request.SubscribeRequest;
@@ -29,6 +33,8 @@ import org.hyperledger.besu.metrics.noop.NoOpMetricsSystem;
 import java.util.HashMap;
 
 import io.vertx.core.Vertx;
+import io.vertx.core.http.ServerWebSocket;
+import io.vertx.core.http.WebSocketFrame;
 import io.vertx.core.json.Json;
 import io.vertx.ext.unit.Async;
 import io.vertx.ext.unit.TestContext;
@@ -36,6 +42,8 @@ import io.vertx.ext.unit.junit.VertxUnitRunner;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
+import org.mockito.ArgumentMatcher;
+import org.mockito.stubbing.Answer;
 
 @RunWith(VertxUnitRunner.class)
 public class EthUnsubscribeIntegrationTest {
@@ -73,19 +81,20 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   @Test
@@ -104,20 +113,21 @@ public class EthUnsubscribeIntegrationTest {
     final JsonRpcRequest unsubscribeRequestBody =
         createEthUnsubscribeRequestBody(subscriptionId2, CONNECTION_ID);
 
-    vertx
-        .eventBus()
-        .consumer(CONNECTION_ID)
-        .handler(
-            msg -> {
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
-              assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
-              async.complete();
-            })
-        .completionHandler(
-            v ->
-                webSocketRequestHandler.handle(CONNECTION_ID, Json.encode(unsubscribeRequestBody)));
+    final JsonRpcSuccessResponse expectedResponse =
+        new JsonRpcSuccessResponse(unsubscribeRequestBody.getId(), Boolean.TRUE);
+
+    final ServerWebSocket websocketMock = mock(ServerWebSocket.class);
+    when(websocketMock.textHandlerID()).thenReturn(CONNECTION_ID);
+    when(websocketMock.writeFrame(argThat(this::isFinalFrame)))
+        .then(completeOnLastFrame(async, websocketMock));
+
+    webSocketRequestHandler.handle(websocketMock, Json.encode(unsubscribeRequestBody));
 
     async.awaitSuccess(ASYNC_TIMEOUT);
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId1)).isNotNull();
+    assertThat(subscriptionManager.getSubscriptionById(subscriptionId2)).isNull();
+    verify(websocketMock).writeFrame(argThat(isFrameWithText(Json.encode(expectedResponse))));
+    verify(websocketMock).writeFrame(argThat(this::isFinalFrame));
   }
 
   private JsonRpcRequest createEthUnsubscribeRequestBody(
@@ -130,4 +140,20 @@ public class EthUnsubscribeIntegrationTest {
             + "\"}",
         WebSocketRpcRequest.class);
   }
+
+  private ArgumentMatcher<WebSocketFrame> isFrameWithText(final String text) {
+    return f -> f.isText() && f.textData().equals(text);
+  }
+
+  private boolean isFinalFrame(final WebSocketFrame frame) {
+    return frame.isFinal();
+  }
+
+  private Answer<ServerWebSocket> completeOnLastFrame(
+      final Async async, final ServerWebSocket websocket) {
+    return invocation -> {
+      async.complete();
+      return websocket;
+    };
+  }
 }
