commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
commit 13f8f65a58bc9a31c8900e12ae2c3ed10003486f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue May 12 11:28:33 2015 +0200

    eth, ethdb: lower the amount of open files & improve err messages for db
    
    Closes #880

diff --git a/eth/backend.go b/eth/backend.go
index 6be871138..80da30086 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -207,21 +207,24 @@ func New(config *Config) (*Ethereum, error) {
 		logger.NewJSONsystem(config.DataDir, config.LogJSON)
 	}
 
+	const dbCount = 3
+	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+
 	newdb := config.NewDB
 	if newdb == nil {
 		newdb = func(path string) (common.Database, error) { return ethdb.NewLDBDatabase(path) }
 	}
 	blockDb, err := newdb(path.Join(config.DataDir, "blockchain"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("blockchain db err: %v", err)
 	}
 	stateDb, err := newdb(path.Join(config.DataDir, "state"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("state db err: %v", err)
 	}
 	extraDb, err := newdb(path.Join(config.DataDir, "extra"))
 	if err != nil {
-		return nil, err
+		return nil, fmt.Errorf("extra db err: %v", err)
 	}
 	nodeDb := path.Join(config.DataDir, "nodes")
 
diff --git a/ethdb/database.go b/ethdb/database.go
index 15af02fdf..c351c024a 100644
--- a/ethdb/database.go
+++ b/ethdb/database.go
@@ -11,7 +11,7 @@ import (
 	"github.com/syndtr/goleveldb/leveldb/opt"
 )
 
-const openFileLimit = 128
+var OpenFileLimit = 64
 
 type LDBDatabase struct {
 	fn string
@@ -26,7 +26,7 @@ type LDBDatabase struct {
 
 func NewLDBDatabase(file string) (*LDBDatabase, error) {
 	// Open the db
-	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: openFileLimit})
+	db, err := leveldb.OpenFile(file, &opt.Options{OpenFilesCacheCapacity: OpenFileLimit})
 	if err != nil {
 		return nil, err
 	}
