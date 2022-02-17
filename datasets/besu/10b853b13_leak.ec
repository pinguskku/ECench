commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
commit 10b853b136850a907a4a455bbed69848e9cdd3bb
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Wed Oct 24 15:21:18 2018 +1000

    [NC-1772] Release DisconnectMessage to avoid leaking memory allocation. (#130)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
index 6c674c59c..cff59037d 100644
--- a/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
+++ b/ethereum/p2p/src/main/java/tech/pegasys/pantheon/ethereum/p2p/netty/ApiHandler.java
@@ -92,6 +92,8 @@ final class ApiHandler extends SimpleChannelInboundHandler<MessageData> {
                 "Received Wire DISCONNECT, but unable to parse reason. Peer: {}",
                 connection.getPeer().getClientId(),
                 e);
+          } finally {
+            disconnect.release();
           }
 
           connection.terminateConnection(reason, true);
