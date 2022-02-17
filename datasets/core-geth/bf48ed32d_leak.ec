commit bf48ed32dd8be6bec2931c9f1eee4fd749affa21
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Aug 3 02:42:45 2015 +0200

    metrics: fix file descriptor leak when reading disk stats on linux
    
    The disk stats file was not closed after reading.

diff --git a/metrics/disk_linux.go b/metrics/disk_linux.go
index e0c8a1a3a..8967d490e 100644
--- a/metrics/disk_linux.go
+++ b/metrics/disk_linux.go
@@ -34,6 +34,7 @@ func ReadDiskStats(stats *DiskStats) error {
 	if err != nil {
 		return err
 	}
+	defer inf.Close()
 	in := bufio.NewReader(inf)
 
 	// Iterate over the IO counter, and extract what we need
