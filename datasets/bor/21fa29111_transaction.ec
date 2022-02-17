commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
commit 21fa29111b3cd12e3748fcb6310e6a18c5562f17
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Mon Jun 15 12:16:29 2015 +0200

    core: reduce max allowed queued txs per address
    
    Transactions in the queue are now capped to a maximum of 200
    transactions. This number is completely arbitrary.

diff --git a/common/types.go b/common/types.go
index 183d48fb3..d05c21eec 100644
--- a/common/types.go
+++ b/common/types.go
@@ -1,6 +1,7 @@
 package common
 
 import (
+	"fmt"
 	"math/big"
 	"math/rand"
 	"reflect"
@@ -95,3 +96,13 @@ func (a *Address) Set(other Address) {
 		a[i] = v
 	}
 }
+
+// PP Pretty Prints a byte slice in the following format:
+// 	hex(value[:4])...(hex[len(value)-4:])
+func PP(value []byte) string {
+	if len(value) <= 8 {
+		return Bytes2Hex(value)
+	}
+
+	return fmt.Sprintf("%x...%x", value[:4], value[len(value)-4])
+}
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index 8f917e96a..ce6fed1a9 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -28,6 +28,10 @@ var (
 	ErrNegativeValue      = errors.New("Negative value")
 )
 
+const (
+	maxQueued = 200 // max limit of queued txs per address
+)
+
 type stateFn func() *state.StateDB
 
 // TxPool contains all currently known transactions. Transactions
@@ -224,6 +228,21 @@ func (self *TxPool) queueTx(hash common.Hash, tx *types.Transaction) {
 		self.queue[from] = make(map[common.Hash]*types.Transaction)
 	}
 	self.queue[from][hash] = tx
+
+	if len(self.queue[from]) > maxQueued {
+		var (
+			worstHash  common.Hash
+			worstNonce uint64
+		)
+		for hash, tx := range self.queue[from] {
+			if tx.Nonce() > worstNonce {
+				worstNonce = tx.Nonce()
+				worstHash = hash
+			}
+		}
+		glog.V(logger.Debug).Infof("Queued tx limit exceeded for %x. Removed worst nonce tx: %x\n", common.PP(from[:]), common.PP(worstHash[:]))
+		delete(self.queue[from], worstHash)
+	}
 }
 
 // addTx will add a transaction to the pending (processable queue) list of transactions
