commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
commit 8f8e52166d731392e2979669c78c6881a41c14a7
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jan 15 12:17:29 2020 +0000

    remove unnecessary Keccak allocation from NedDataFeed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
index ae1d30542..843c3b924 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/FastSync/NodeDataFeed.cs
@@ -466,7 +466,7 @@ namespace Nethermind.Blockchain.Synchronization.FastSync
                         }
 
                         /* node sent data that is not consistent with its hash - it happens surprisingly often */
-                        if (Keccak.Compute(currentResponseItem) != currentStateSyncItem.Hash)
+                        if(ValueKeccak.Compute(currentResponseItem).BytesAsSpan.SequenceEqual(currentStateSyncItem.Hash.Bytes))
                         {
                             if (_logger.IsTrace) _logger.Trace($"Peer sent invalid data (batch {requestLength}->{responseLength}) of length {batch.Responses[i]?.Length} of type {batch.RequestedNodes[i].NodeDataType} at level {batch.RequestedNodes[i].Level} of type {batch.RequestedNodes[i].NodeDataType} Keccak({batch.Responses[i].ToHexString()}) != {batch.RequestedNodes[i].Hash}");
                             invalidNodes++;
diff --git a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
index 03ebc9ab4..e8ab0c6bc 100644
--- a/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
+++ b/src/Nethermind/Nethermind.Network/MessageSerializationService.cs
@@ -41,6 +41,7 @@ namespace Nethermind.Network
                 return zeroSerializer.Deserialize(buffer);
             }
 
+            // during fast sync this is where 15% of allocations happen and this is entirely unnecessary
             return serializer.Deserialize(buffer.ReadAllBytes());
         }
 
