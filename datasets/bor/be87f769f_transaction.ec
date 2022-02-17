commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
commit be87f769f676cbe3bf028e856160396ed08c64fc
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Mar 8 14:23:28 2021 +0100

    core/types: reduce allocations in GasPriceCmp (#22456)

diff --git a/core/types/transaction.go b/core/types/transaction.go
index 49127630a..a35e07a5a 100644
--- a/core/types/transaction.go
+++ b/core/types/transaction.go
@@ -293,7 +293,7 @@ func (tx *Transaction) RawSignatureValues() (v, r, s *big.Int) {
 
 // GasPriceCmp compares the gas prices of two transactions.
 func (tx *Transaction) GasPriceCmp(other *Transaction) int {
-	return tx.inner.gasPrice().Cmp(other.GasPrice())
+	return tx.inner.gasPrice().Cmp(other.inner.gasPrice())
 }
 
 // GasPriceIntCmp compares the gas price of the transaction against the given price.
