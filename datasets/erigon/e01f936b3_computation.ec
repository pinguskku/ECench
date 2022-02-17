commit e01f936b35baa33c9c204353dca7118ffc0b7870
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Sat Jul 11 09:56:29 2020 +0700

    improve dupsort experiment (#737)

diff --git a/cmd/hack/hack.go b/cmd/hack/hack.go
index d23d115e5..1d35f387c 100644
--- a/cmd/hack/hack.go
+++ b/cmd/hack/hack.go
@@ -1640,22 +1640,27 @@ func dupSortState(chaindata string) {
 		var createErr error
 		newStateBucket, createErr = tx.OpenDBI(string(dbutils.CurrentStateBucket), lmdb.Create|lmdb.DupSort)
 		check(createErr)
+		err = tx.Drop(newStateBucket, false)
+		check(err)
+		return nil
+	})
+	check(err)
+
+	var newStateBucket2 lmdb.DBI
+	err = env2.Update(func(tx *lmdb.Txn) error {
+		var createErr error
+		newStateBucket2, createErr = tx.OpenDBI(string(dbutils.CurrentStateBucket), lmdb.Create)
+		check(createErr)
+		err = tx.Drop(newStateBucket2, false)
+		check(err)
 		return nil
 	})
 	check(err)
 
 	err = db.KV().View(context.Background(), func(tx ethdb.Tx) error {
 		b := tx.Bucket(dbutils.CurrentStateBucket)
-		sz, _ := b.Size()
-		fmt.Printf("Current State bucket size: %s\n", common.StorageSize(sz))
-
 		txn, _ := env.BeginTxn(nil, 0)
-		err = txn.Drop(newStateBucket, false)
-		check(err)
-
 		txn2, _ := env2.BeginTxn(nil, 0)
-		err = txn2.Drop(newStateBucket, false)
-		check(err)
 
 		c := b.Cursor()
 		i := 0
@@ -1672,18 +1677,17 @@ func dupSortState(chaindata string) {
 				fmt.Printf("%x\n", k[:2])
 			}
 
+			err = txn2.Put(newStateBucket2, common.CopyBytes(k), common.CopyBytes(v), 0)
+			check(err)
+
 			if len(k) == common.HashLength {
 				err = txn.Put(newStateBucket, common.CopyBytes(k), common.CopyBytes(v), lmdb.AppendDup)
 				check(err)
-				err = txn2.Put(newStateBucket, common.CopyBytes(k), common.CopyBytes(v), lmdb.Append)
-				check(err)
 			} else {
 				prefix := k[:common.HashLength+common.IncarnationLength]
 				suffix := k[common.HashLength+common.IncarnationLength:]
 				err = txn.Put(newStateBucket, common.CopyBytes(prefix), append(suffix, v...), lmdb.AppendDup)
 				check(err)
-				err = txn2.Put(newStateBucket, common.CopyBytes(k), common.CopyBytes(v), lmdb.Append)
-				check(err)
 			}
 		}
 		err = txn.Commit()
@@ -1695,10 +1699,23 @@ func dupSortState(chaindata string) {
 	})
 	check(err)
 
+	err = env2.View(func(txn *lmdb.Txn) (err error) {
+		st, err := txn.Stat(newStateBucket2)
+		check(err)
+		fmt.Printf("Current bucket size: %s\n", common.StorageSize((st.LeafPages+st.BranchPages+st.OverflowPages)*uint64(os.Getpagesize())))
+		return nil
+	})
+	check(err)
+
 	err = env.View(func(txn *lmdb.Txn) (err error) {
 		st, err := txn.Stat(newStateBucket)
 		check(err)
-		fmt.Printf("Current bucket size: %s\n", common.StorageSize((st.LeafPages+st.BranchPages+st.OverflowPages)*uint64(os.Getpagesize())))
+		fmt.Printf("New bucket size: %s\n", common.StorageSize((st.LeafPages+st.BranchPages+st.OverflowPages)*uint64(os.Getpagesize())))
+		return nil
+	})
+	check(err)
+
+	err = env.View(func(txn *lmdb.Txn) (err error) {
 
 		cur, err := txn.OpenCursor(newStateBucket)
 		check(err)
