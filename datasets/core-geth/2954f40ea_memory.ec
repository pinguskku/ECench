commit 2954f40eac5c15e09085c47f135e6628ade6a822
Author: lmittmann <lmittmann@users.noreply.github.com>
Date:   Thu Oct 21 11:43:23 2021 +0200

    common/hexutil: improve performance of EncodeBig (#23780)
    
    - use Text instead of fmt.Sprintf
    - reduced allocs from 6 to 2
    - improved speed

diff --git a/common/hexutil/hexutil.go b/common/hexutil/hexutil.go
index 46223a281..e0241f5f2 100644
--- a/common/hexutil/hexutil.go
+++ b/common/hexutil/hexutil.go
@@ -176,13 +176,14 @@ func MustDecodeBig(input string) *big.Int {
 }
 
 // EncodeBig encodes bigint as a hex string with 0x prefix.
-// The sign of the integer is ignored.
 func EncodeBig(bigint *big.Int) string {
-	nbits := bigint.BitLen()
-	if nbits == 0 {
+	if sign := bigint.Sign(); sign == 0 {
 		return "0x0"
+	} else if sign > 0 {
+		return "0x" + bigint.Text(16)
+	} else {
+		return "-0x" + bigint.Text(16)[1:]
 	}
-	return fmt.Sprintf("%#x", bigint)
 }
 
 func has0xPrefix(input string) bool {
diff --git a/common/hexutil/hexutil_test.go b/common/hexutil/hexutil_test.go
index ed6fccc3c..f2b800d82 100644
--- a/common/hexutil/hexutil_test.go
+++ b/common/hexutil/hexutil_test.go
@@ -201,3 +201,15 @@ func TestDecodeUint64(t *testing.T) {
 		}
 	}
 }
+
+func BenchmarkEncodeBig(b *testing.B) {
+	for _, bench := range encodeBigTests {
+		b.Run(bench.want, func(b *testing.B) {
+			b.ReportAllocs()
+			bigint := bench.input.(*big.Int)
+			for i := 0; i < b.N; i++ {
+				EncodeBig(bigint)
+			}
+		})
+	}
+}
