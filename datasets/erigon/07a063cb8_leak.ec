commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
commit 07a063cb8a06a6f284e21adf1c70e937ea697a44
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Thu Apr 29 00:00:32 2021 +0700

    txn full fix - cursors leak (#1838)

diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index c4c033c92..b93cf1af7 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -657,6 +657,7 @@ func (tx *lmdbTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -670,6 +671,7 @@ func (tx *lmdbTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 	err := tx.tx.Del(lmdb.DBI(b.DBI), k, v)
diff --git a/ethdb/kv_mdbx.go b/ethdb/kv_mdbx.go
index efbd2e5e1..a027b34b6 100644
--- a/ethdb/kv_mdbx.go
+++ b/ethdb/kv_mdbx.go
@@ -712,6 +712,7 @@ func (tx *MdbxTx) Put(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Put(k, v)
 	}
 
@@ -725,6 +726,7 @@ func (tx *MdbxTx) Delete(bucket string, k, v []byte) error {
 		if err != nil {
 			return err
 		}
+		defer c.Close()
 		return c.Delete(k, v)
 	}
 
