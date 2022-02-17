commit 60454da6507f9f391e7943e002136b8e84c32521
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Jul 1 01:20:49 2015 +0300

    eth/downloader: reduce hash fetches in prep for eth/61

diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index b4154c166..ce85aec17 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -25,9 +25,9 @@ const (
 )
 
 var (
-	MinHashFetch  = 512  // Minimum amount of hashes to not consider a peer stalling
-	MaxHashFetch  = 2048 // Amount of hashes to be fetched per retrieval request
-	MaxBlockFetch = 128  // Amount of blocks to be fetched per retrieval request
+	MinHashFetch  = 512 // Minimum amount of hashes to not consider a peer stalling
+	MaxHashFetch  = 512 // Amount of hashes to be fetched per retrieval request
+	MaxBlockFetch = 128 // Amount of blocks to be fetched per retrieval request
 
 	hashTTL         = 5 * time.Second  // Time it takes for a hash request to time out
 	blockSoftTTL    = 3 * time.Second  // Request completion threshold for increasing or decreasing a peer's bandwidth
