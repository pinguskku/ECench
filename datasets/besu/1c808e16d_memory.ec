commit 1c808e16d6e408a2ace7091cd043421f7b33a927
Author: mbaxter <mbaxter@users.noreply.github.com>
Date:   Tue Mar 5 11:07:32 2019 -0500

    Don't make unnecessary copies of data in RocksDbKeyValueStorage (#1040)
    
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/services/kvstore/src/main/java/tech/pegasys/pantheon/services/kvstore/RocksDbKeyValueStorage.java b/services/kvstore/src/main/java/tech/pegasys/pantheon/services/kvstore/RocksDbKeyValueStorage.java
index 2909ea908..c39e57368 100644
--- a/services/kvstore/src/main/java/tech/pegasys/pantheon/services/kvstore/RocksDbKeyValueStorage.java
+++ b/services/kvstore/src/main/java/tech/pegasys/pantheon/services/kvstore/RocksDbKeyValueStorage.java
@@ -96,7 +96,7 @@ public class RocksDbKeyValueStorage implements KeyValueStorage, Closeable {
     throwIfClosed();
 
     try (final OperationTimer.TimingContext ignored = readLatency.startTimer()) {
-      return Optional.ofNullable(db.get(key.extractArray())).map(BytesValue::wrap);
+      return Optional.ofNullable(db.get(key.getArrayUnsafe())).map(BytesValue::wrap);
     } catch (final RocksDBException e) {
       throw new StorageException(e);
     }
@@ -192,7 +192,7 @@ public class RocksDbKeyValueStorage implements KeyValueStorage, Closeable {
     @Override
     protected void doPut(final BytesValue key, final BytesValue value) {
       try (final OperationTimer.TimingContext ignored = writeLatency.startTimer()) {
-        innerTx.put(key.extractArray(), value.extractArray());
+        innerTx.put(key.getArrayUnsafe(), value.getArrayUnsafe());
       } catch (final RocksDBException e) {
         throw new StorageException(e);
       }
@@ -201,7 +201,7 @@ public class RocksDbKeyValueStorage implements KeyValueStorage, Closeable {
     @Override
     protected void doRemove(final BytesValue key) {
       try (final OperationTimer.TimingContext ignored = removeLatency.startTimer()) {
-        innerTx.delete(key.extractArray());
+        innerTx.delete(key.getArrayUnsafe());
       } catch (final RocksDBException e) {
         throw new StorageException(e);
       }