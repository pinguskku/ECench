commit 8bc293b3f7c1932ad76bb3ab54a82d1b6ddd1591
Author: Igor Mandrigin <mandrigin@users.noreply.github.com>
Date:   Wed Aug 5 11:54:19 2020 +0200

    Remove unnecessary memory profiling (#872)
    
    * remove separate memory profiling from staged sync
    
    * don’t run pprof globally always

diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index 38671494a..6e0fd549e 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -42,10 +42,6 @@ import (
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ledgerwatch/turbo-geth/metrics"
 	"github.com/ledgerwatch/turbo-geth/node"
-
-	"net/http"
-	//nolint:gosec
-	_ "net/http/pprof"
 )
 
 const (
@@ -264,9 +260,6 @@ func init() {
 }
 
 func main() {
-	go func() {
-		log.Info("HTTP", "error", http.ListenAndServe("localhost:6060", nil))
-	}()
 	if err := app.Run(os.Args); err != nil {
 		fmt.Fprintln(os.Stderr, err)
 		os.Exit(1)
diff --git a/eth/stagedsync/stage_execute.go b/eth/stagedsync/stage_execute.go
index d49f36aea..ca908eb3f 100644
--- a/eth/stagedsync/stage_execute.go
+++ b/eth/stagedsync/stage_execute.go
@@ -112,14 +112,6 @@ func SpawnExecuteBlocksStage(s *StageState, stateDB ethdb.Database, chainConfig
 			if blockNum-s.BlockNumber == 100000 {
 				// Flush the CPU profiler
 				pprof.StopCPUProfile()
-
-				// And the memory profiler
-				f, _ := os.Create(fmt.Sprintf("mem-%d.prof", s.BlockNumber))
-				runtime.GC()
-				if err = pprof.WriteHeapProfile(f); err != nil {
-					log.Error("could not save memory profile", "error", err)
-				}
-				f.Close()
 			}
 		}
 
