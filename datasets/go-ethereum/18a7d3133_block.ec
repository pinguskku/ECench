commit 18a7d313386194be39e733ac3043988690f42464
Author: Jim McDonald <Jim@mcdee.net>
Date:   Mon Jan 15 10:57:06 2018 +0000

    miner: avoid unnecessary work (#15883)

diff --git a/core/gaspool.go b/core/gaspool.go
index c3ee5c198..e3795c1ee 100644
--- a/core/gaspool.go
+++ b/core/gaspool.go
@@ -44,6 +44,11 @@ func (gp *GasPool) SubGas(amount uint64) error {
 	return nil
 }
 
+// Gas returns the amount of gas remaining in the pool.
+func (gp *GasPool) Gas() uint64 {
+	return uint64(*gp)
+}
+
 func (gp *GasPool) String() string {
 	return fmt.Sprintf("%d", *gp)
 }
diff --git a/miner/worker.go b/miner/worker.go
index 638f759bf..1520277e1 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -512,6 +512,11 @@ func (env *Work) commitTransactions(mux *event.TypeMux, txs *types.TransactionsB
 	var coalescedLogs []*types.Log
 
 	for {
+		// If we don't have enough gas for any further transactions then we're done
+		if gp.Gas() < params.TxGas {
+			log.Trace("Not enough gas for further transactions", "gp", gp)
+			break
+		}
 		// Retrieve the next transaction and abort if all done
 		tx := txs.Peek()
 		if tx == nil {
