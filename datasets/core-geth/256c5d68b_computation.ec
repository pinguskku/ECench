commit 256c5d68b245899f6d37c72636fdd795f66397ee
Author: Gregory Markou <16929357+GregTheGreek@users.noreply.github.com>
Date:   Wed Apr 28 03:06:34 2021 -0400

    eth/gasprice: improve stability of estimated price (#22722)
    
    This PR makes the gas price oracle ignore transactions priced at `<=1 wei`.

diff --git a/eth/gasprice/gasprice.go b/eth/gasprice/gasprice.go
index 5d8be08e0..560722bec 100644
--- a/eth/gasprice/gasprice.go
+++ b/eth/gasprice/gasprice.go
@@ -199,6 +199,9 @@ func (gpo *Oracle) getBlockPrices(ctx context.Context, signer types.Signer, bloc
 
 	var prices []*big.Int
 	for _, tx := range txs {
+		if tx.GasPriceIntCmp(common.Big1) <= 0 {
+			continue
+		}
 		sender, err := types.Sender(signer, tx)
 		if err == nil && sender != block.Coinbase() {
 			prices = append(prices, tx.GasPrice())
