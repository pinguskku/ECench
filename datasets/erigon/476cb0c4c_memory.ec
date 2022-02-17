commit 476cb0c4c1de41fd4d22b1101d3772a830d47553
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation
    
    # Conflicts:
    #       core/state/snapshot/generate.go
    #       core/state/snapshot/journal.go
    #       core/state/snapshot/snapshot.go

diff --git a/to-merge.txt b/to-merge.txt
index 2b7ae0519..1ce9585cc 100644
--- a/to-merge.txt
+++ b/to-merge.txt
@@ -75,93 +75,3 @@ Date:   Mon Aug 24 13:22:36 2020 +0300
 
     core/state/snapshot: reduce disk layer depth during generation
 
