commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
commit a36637962914ff5a19fefb4a4cd51bbcdbba1ece
Author: Sally MacFarlane <sally.macfarlane@consensys.net>
Date:   Thu May 6 12:38:14 2021 +1000

    entropy - reduce parallelism (#2228)
    
    * reduce parallelism to 6
    
    Signed-off-by: Sally MacFarlane <sally.macfarlane@consensys.net>

diff --git a/.circleci/config.yml b/.circleci/config.yml
index 820de35df..a727152b9 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -173,7 +173,7 @@ jobs:
       - capture_test_results
 
   acceptanceTests:
-    parallelism: 8
+    parallelism: 6
     executor: besu_executor_xl
     steps:
       - prepare
