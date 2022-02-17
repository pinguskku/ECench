commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
commit 99be62a9b16fd7b3d1e2e17f1e571d3bef34f122
Author: fomotrader <82184770+fomotrader@users.noreply.github.com>
Date:   Mon Dec 20 13:25:46 2021 +0400

    accounts/abi: avoid unnecessary alloc (#24128)

diff --git a/accounts/abi/unpack.go b/accounts/abi/unpack.go
index ec0698493..43cd6c645 100644
--- a/accounts/abi/unpack.go
+++ b/accounts/abi/unpack.go
@@ -290,7 +290,7 @@ func tuplePointsTo(index int, output []byte) (start int, err error) {
 	offset := big.NewInt(0).SetBytes(output[index : index+32])
 	outputLen := big.NewInt(int64(len(output)))
 
-	if offset.Cmp(big.NewInt(int64(len(output)))) > 0 {
+	if offset.Cmp(outputLen) > 0 {
 		return 0, fmt.Errorf("abi: cannot marshal in to go slice: offset %v would go over slice boundary (len=%v)", offset, outputLen)
 	}
 	if offset.BitLen() > 63 {
