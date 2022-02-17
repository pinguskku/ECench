commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
commit 5ae602e9a42ea40a5302581beb038062abfd5dea
Author: alex.sharov <AskAlexSharov@gmail.com>
Date:   Mon Mar 8 18:58:44 2021 +0700

    less metrics performance impact

diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 20b77914d..d64a48173 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -30,11 +30,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-)
-
-var (
-	dbGetTimer = metrics.NewRegisteredTimer("db/get", nil)
 )
 
 type DbCopier interface {
diff --git a/ethdb/tx_db.go b/ethdb/tx_db.go
index 046b1f06d..4a36f5849 100644
--- a/ethdb/tx_db.go
+++ b/ethdb/tx_db.go
@@ -113,9 +113,9 @@ func (m *TxDb) Last(bucket string) ([]byte, []byte, error) {
 }
 
 func (m *TxDb) Get(bucket string, key []byte) ([]byte, error) {
-	if metrics.Enabled {
-		defer dbGetTimer.UpdateSince(time.Now())
-	}
+	//if metrics.Enabled {
+	//	defer dbGetTimer.UpdateSince(time.Now())
+	//}
 
 	_, v, err := m.cursor(bucket).SeekExact(key)
 	if err != nil {
