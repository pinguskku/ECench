commit 1e7f628fc0523477ebfbde664f9558fb6bfd54d4
Author: meows <b5c6@protonmail.com>
Date:   Wed Sep 23 08:28:35 2020 -0500

    core: (lint) goimports -w, unnecessary conversions
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/core/blockchain_af.go b/core/blockchain_af.go
index 1f3839e1e..90670df25 100644
--- a/core/blockchain_af.go
+++ b/core/blockchain_af.go
@@ -101,7 +101,7 @@ func (bc *BlockChain) ecbp1100(commonAncestor, current, proposed *types.Header)
 		return fmt.Errorf(`%w: ECBP1100-MESS 🔒 status=rejected age=%v current.span=%v proposed.span=%v tdr/gravity=%0.6f common.bno=%d common.hash=%s current.bno=%d current.hash=%s proposed.bno=%d proposed.hash=%s`,
 			errReorgFinality,
 			common.PrettyAge(time.Unix(int64(commonAncestor.Time), 0)),
-			common.PrettyDuration(time.Duration(current.Time - commonAncestor.Time)*time.Second),
+			common.PrettyDuration(time.Duration(current.Time-commonAncestor.Time)*time.Second),
 			common.PrettyDuration(time.Duration(int32(xBig.Uint64()))*time.Second),
 			prettyRatio,
 			commonAncestor.Number.Uint64(), commonAncestor.Hash().Hex(),
@@ -173,7 +173,6 @@ func ecbp1100PolynomialV(x *big.Int) *big.Int {
 	return out
 }
 
-var big0 = big.NewInt(0)
 var big2 = big.NewInt(2)
 var big3 = big.NewInt(3)
 
@@ -195,15 +194,16 @@ var ecbp1100PolynomialVHeight = new(big.Int).Mul(new(big.Int).Mul(ecbp1100Polyno
 
 /*
 ecbp1100PolynomialVI64 is an int64 implementation of ecbp1100PolynomialV.
- */
+*/
 func ecbp1100PolynomialVI64(x int64) int64 {
 	if x > ecbp1100PolynomialVXCapI64 {
 		x = ecbp1100PolynomialVXCapI64
 	}
 	return ecbp1100PolynomialVCurveFunctionDenominatorI64 +
-		((3 * emath.BigPow(int64(x), 2).Int64()) - (2 * emath.BigPow(int64(x), 3).Int64() / ecbp1100PolynomialVXCapI64)) *
-		ecbp1100PolynomialVHeightI64 / (emath.BigPow(ecbp1100PolynomialVXCapI64, 2).Int64())
+		((3*emath.BigPow(x, 2).Int64())-(2*emath.BigPow(x, 3).Int64()/ecbp1100PolynomialVXCapI64))*
+			ecbp1100PolynomialVHeightI64/(emath.BigPow(ecbp1100PolynomialVXCapI64, 2).Int64())
 }
+
 var ecbp1100PolynomialVCurveFunctionDenominatorI64 = int64(128)
 var ecbp1100PolynomialVXCapI64 = int64(25132)
 var ecbp1100PolynomialVAmplI64 = int64(15)
@@ -253,4 +253,3 @@ f(x)=1.0001^(x)
 func ecbp1100AGExpA(x float64) (antiGravity float64) {
 	return math.Pow(1.0001, x)
 }
-
diff --git a/core/blockchain_af_test.go b/core/blockchain_af_test.go
index 1a9f0b83c..bfa8988fb 100644
--- a/core/blockchain_af_test.go
+++ b/core/blockchain_af_test.go
@@ -440,7 +440,7 @@ will hit writeBlockWithState.
 
 AF needs to be implemented at both sites to prevent re-proposed chains from sidestepping
 the AF criteria.
- */
+*/
 func TestAFKnownBlock(t *testing.T) {
 	engine := ethash.NewFaker()
 
@@ -557,7 +557,6 @@ func TestGenerateChainTargetingHashrate(t *testing.T) {
 	t.Log(chain.CurrentBlock().Number())
 }
 
-
 func TestBlockChain_AF_Difficulty_Develop(t *testing.T) {
 	t.Skip("Development version of tests with plotter")
 	// Generate the original common chain segment and the two competing forks
