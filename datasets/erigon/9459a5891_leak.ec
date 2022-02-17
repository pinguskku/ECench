commit 9459a5891875d135047070b8fd25f9b3823462a6
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Tue Jun 9 09:43:33 2020 +0700

    fix lmdb mem leak (#640)

diff --git a/go.mod b/go.mod
index 0d567a883..2db40fcba 100644
--- a/go.mod
+++ b/go.mod
@@ -3,7 +3,7 @@ module github.com/ledgerwatch/turbo-geth
 go 1.13
 
 require (
-	github.com/AskAlexSharov/lmdb-go v1.8.1-0.20200608080821-6fdb53b47e78
+	github.com/AskAlexSharov/lmdb-go v1.8.1-0.20200609024141-123c53568c38
 	github.com/Azure/azure-storage-blob-go v0.8.0
 	github.com/Azure/go-autorest/autorest/adal v0.8.3 // indirect
 	github.com/JekaMas/notify v0.9.4
diff --git a/go.sum b/go.sum
index 17eaabe30..aaa74b378 100644
--- a/go.sum
+++ b/go.sum
@@ -1,6 +1,6 @@
 cloud.google.com/go v0.26.0/go.mod h1:aQUYkXzVsufM+DwF1aE+0xfcU+56JwCaLick0ClmMTw=
-github.com/AskAlexSharov/lmdb-go v1.8.1-0.20200608080821-6fdb53b47e78 h1:oHoQ7THIToKhelqoWL296YCGV8yogP4KtQQuqfPMKO4=
-github.com/AskAlexSharov/lmdb-go v1.8.1-0.20200608080821-6fdb53b47e78/go.mod h1:k7Jo/kN60Hq1MTBwsVSp2JllEs5Tyhd4MZ7tY9smjeA=
+github.com/AskAlexSharov/lmdb-go v1.8.1-0.20200609024141-123c53568c38 h1:0lvFLmXBPIKQSwbMBc6CC+v93gqWn/wiwmlEs1/EURE=
+github.com/AskAlexSharov/lmdb-go v1.8.1-0.20200609024141-123c53568c38/go.mod h1:k7Jo/kN60Hq1MTBwsVSp2JllEs5Tyhd4MZ7tY9smjeA=
 github.com/Azure/azure-pipeline-go v0.2.1 h1:OLBdZJ3yvOn2MezlWvbrBMTEUQC72zAftRZOMdj5HYo=
 github.com/Azure/azure-pipeline-go v0.2.1/go.mod h1:UGSo8XybXnIGZ3epmeBw7Jdz+HiUVpqIlpz/HKHylF4=
 github.com/Azure/azure-storage-blob-go v0.8.0 h1:53qhf0Oxa0nOjgbDeeYPUeyiNmafAFEY95rZLK0Tj6o=
