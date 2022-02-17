commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
commit d5c2e5fd9ab879927c351538aebe37b4a8cb2f43
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 27 08:37:23 2021 +0100

    checkChangeSet to work with MDBX, load senders for better performance (#2024)
    
    * CheckchangeSets switch to MDBX
    
    * Load senders
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/state/commands/check_change_sets.go b/cmd/state/commands/check_change_sets.go
index 3c0499c48..42b493dc6 100644
--- a/cmd/state/commands/check_change_sets.go
+++ b/cmd/state/commands/check_change_sets.go
@@ -64,7 +64,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		interruptCh <- true
 	}()
 
-	chainDb := ethdb.MustOpen(chaindata)
+	kv, err := ethdb.NewMDBX().Path(chaindata).Open()
+	if err != nil {
+		return err
+	}
+	chainDb := ethdb.NewObjectDatabase(kv)
 	defer chainDb.Close()
 	historyDb := chainDb
 	if chaindata != historyfile {
@@ -113,7 +117,11 @@ func CheckChangeSets(genesis *core.Genesis, blockNum uint64, chaindata string, h
 		if err != nil {
 			return err
 		}
-		block := rawdb.ReadBlock(rwtx, blockHash, blockNum)
+		var block *types.Block
+		block, _, err = rawdb.ReadBlockWithSenders(rwtx, blockHash, blockNum)
+		if err != nil {
+			return err
+		}
 		if block == nil {
 			break
 		}
