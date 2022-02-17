commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
commit 8ef56242dd23b7e243c4fbf10073233639f563cc
Author: Adrian Sutton <adrian@symphonious.net>
Date:   Tue Mar 19 10:29:22 2019 +1000

    Reduce number of seen blocks and transactions Pantheon tracks to lower required memory. (#1112)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
index 4e92d7e91..756972b00 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/manager/EthPeer.java
@@ -48,7 +48,7 @@ public class EthPeer {
   private static final Logger LOG = LogManager.getLogger();
   private final PeerConnection connection;
 
-  private final int maxTrackedSeenBlocks = 30_000;
+  private final int maxTrackedSeenBlocks = 300;
 
   private final Set<Hash> knownBlocks;
   private final String protocolName;
diff --git a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
index 01518c3cd..92f010619 100644
--- a/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
+++ b/ethereum/eth/src/main/java/tech/pegasys/pantheon/ethereum/eth/transactions/PeerTransactionTracker.java
@@ -27,7 +27,7 @@ import java.util.Set;
 import java.util.concurrent.ConcurrentHashMap;
 
 class PeerTransactionTracker implements DisconnectCallback {
-  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 30_000;
+  private static final int MAX_TRACKED_SEEN_TRANSACTIONS = 10_000;
   private final Map<EthPeer, Set<Hash>> seenTransactions = new ConcurrentHashMap<>();
   private final Map<EthPeer, Set<Transaction>> transactionsToSend = new ConcurrentHashMap<>();
 
