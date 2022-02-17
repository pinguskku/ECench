commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
commit 1c24b9371eefc9fe15f0f78b3182223111db3ca2
Author: ledgerwatch <akhounov@gmail.com>
Date:   Mon Jul 19 18:50:45 2021 +0100

    Refactoring of rpctest to reduce copy-paste and enable error recording (#2401)
    
    * Refactoring of rpctest to reduce copy-paste and enable error recording
    
    * Reduction
    
    Co-authored-by: Alexey Sharp <alexeysharp@Alexeys-iMac.local>

diff --git a/cmd/rpctest/main.go b/cmd/rpctest/main.go
index b3f58ff58..6e1617bd6 100644
--- a/cmd/rpctest/main.go
+++ b/cmd/rpctest/main.go
@@ -42,7 +42,7 @@ func main() {
 		cmd.Flags().StringVar(&recordFile, "recordFile", "", "File where to record requests and responses to")
 	}
 	withErrorFile := func(cmd *cobra.Command) {
-		cmd.Flags().StringVar(&recordFile, "errorFile", "", "File where to record errors (when responses do not match)")
+		cmd.Flags().StringVar(&errorFile, "errorFile", "", "File where to record errors (when responses do not match)")
 	}
 	with := func(cmd *cobra.Command, opts ...func(*cobra.Command)) {
 		for i := range opts {
@@ -123,10 +123,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchEthGetLogs(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchEthGetLogsCmd, withErigonUrl, withGethUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var bench9Cmd = &cobra.Command{
 		Use:   "bench9",
@@ -143,10 +143,10 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallCmd = &cobra.Command{
 		Use:   "benchTraceCall",
@@ -163,60 +163,60 @@ func main() {
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchDebugTraceCall(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchDebugTraceCallCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceCallManyCmd = &cobra.Command{
 		Use:   "benchTraceCallMany",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceCallMany(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceCallManyCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceBlockCmd = &cobra.Command{
 		Use:   "benchTraceBlock",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceBlock(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceBlockCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceFilterCmd = &cobra.Command{
 		Use:   "benchTraceFilter",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceFilter(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceFilterCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTxReceiptCmd = &cobra.Command{
 		Use:   "benchTxReceipt",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTxReceipt(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTxReceiptCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var benchTraceReplayTransactionCmd = &cobra.Command{
 		Use:   "benchTraceReplayTransaction",
 		Short: "",
 		Long:  ``,
 		Run: func(cmd *cobra.Command, args []string) {
-			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile)
+			rpctest.BenchTraceReplayTransaction(erigonURL, gethURL, needCompare, blockFrom, blockTo, recordFile, errorFile)
 		},
 	}
-	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord)
+	with(benchTraceReplayTransactionCmd, withGethUrl, withErigonUrl, withNeedCompare, withBlockNum, withRecord, withErrorFile)
 
 	var replayCmd = &cobra.Command{
 		Use:   "replay",
diff --git a/cmd/rpctest/rpctest/bench_debugtracecall.go b/cmd/rpctest/rpctest/bench_debugtracecall.go
index a67f954a6..e4acd7812 100644
--- a/cmd/rpctest/rpctest/bench_debugtracecall.go
+++ b/cmd/rpctest/rpctest/bench_debugtracecall.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -82,40 +93,11 @@ func BenchDebugTraceCall(erigonURL, gethURL string, needCompare bool, blockFrom
 			reqGen.reqID++
 
 			request := reqGen.debugTraceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res := reqGen.Erigon2("debug_traceCall", request)
-			if res.Err != nil {
-				fmt.Printf("Could not debug traceCall (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceCall", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error debugging call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceCall", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not debug traceCall (geth) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error debugging call (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different debug traceCall block %d, tx %x: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_ethgetlogs.go b/cmd/rpctest/rpctest/bench_ethgetlogs.go
index 1ce365b70..f3a8fe086 100644
--- a/cmd/rpctest/rpctest/bench_ethgetlogs.go
+++ b/cmd/rpctest/rpctest/bench_ethgetlogs.go
@@ -7,11 +7,9 @@ import (
 	"net/http"
 	"os"
 	"time"
-
-	"github.com/ledgerwatch/erigon/log"
 )
 
-func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -28,6 +26,17 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 	resultsCh := make(chan CallResult, 1000)
 	defer close(resultsCh)
 	go vegetaWrite(false, []string{"debug_getModifiedAccountsByNumber", "eth_getLogs"}, resultsCh)
@@ -70,85 +79,22 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
 				reqGen.reqID++
-				startErigon := time.Now()
 				request := reqGen.getLogs(prevBn, bn, account)
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
-				res = reqGen.Erigon2("eth_getLogs", request)
-				durationErigon := time.Since(startErigon).Seconds()
-				if res.Err != nil {
-					fmt.Printf("Could not get logs for account (Erigon) %x: %v\n", account, res.Err)
+				errCtx := fmt.Sprintf("account %x blocks %d-%d", account, prevBn, bn)
+				if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error getting logs for account (Erigon) %x: %d %s\n", account, errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				var durationG float64
-				if needCompare {
-					startG := time.Now()
-					resg := reqGen.Geth2("eth_getLogs", request)
-					durationG = time.Since(startG).Seconds()
-					resultsCh <- res
-					if resg.Err != nil {
-						fmt.Printf("Could not get logs for account (geth) %x: %v\n", account, resg.Err)
-						recording = false
-					} else if errValg := resg.Result.Get("error"); errValg != nil {
-						fmt.Printf("Error getting logs for account (geth) %x: %d %s\n", account, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-						recording = false
-					} else {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different logs for account %x and block %d-%d\n", account, prevBn, bn)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				topics := getTopics(res.Result)
 				// All combination of account and one topic
 				for _, topic := range topics {
 					reqGen.reqID++
-					startErigon := time.Now()
 					request = reqGen.getLogs1(prevBn, bn+10000, account, topic)
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					durationErigon := time.Since(startErigon).Seconds()
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x: %v\n", account, topic, res.Err)
-						return
-					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x: %d %s\n", account, topic, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+					errCtx := fmt.Sprintf("account %x topic %x blocks %d-%d", account, topic, prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if needCompare {
-						startG := time.Now()
-						resg := reqGen.Geth2("eth_getLogs", request)
-						durationG = time.Since(startG).Seconds()
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x: %v\n", account, topic, resg.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x: %d %s\n", account, topic, errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x and block %d-%d\n", account, topic, prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")), "durationErigon", durationErigon, "durationG", durationG)
 				}
 				// Random combinations of two topics
 				if len(topics) >= 2 {
@@ -159,38 +105,11 @@ func BenchEthGetLogs(erigonURL, gethURL string, needCompare bool, blockFrom uint
 					}
 					reqGen.reqID++
 					request = reqGen.getLogs2(prevBn, bn+100000, account, topics[idx1], topics[idx2])
-					recording = rec != nil
-					res = reqGen.Erigon2("eth_getLogs", request)
-					if res.Err != nil {
-						fmt.Printf("Could not get logs for account (Erigon) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
+					errCtx := fmt.Sprintf("account %x topic1 %x topic2 %x blocks %d-%d", account, topics[idx1], topics[idx2], prevBn, bn)
+					if err := requestAndCompare(request, "eth_getLogs", errCtx, reqGen, needCompare, rec, errs); err != nil {
+						fmt.Println(err)
 						return
 					}
-					if errVal := res.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error getting logs for account (Erigon) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if needCompare {
-						resg := reqGen.Geth2("eth_getLogs", request)
-						resultsCh <- res
-						if resg.Err != nil {
-							fmt.Printf("Could not get logs for account (geth) %x %x %x: %v\n", account, topics[idx1], topics[idx2], res.Err)
-							recording = false
-						} else if errValg := resg.Result.Get("error"); errValg != nil {
-							fmt.Printf("Error getting logs for account (geth) %x %x %x: %d %s\n", account, topics[idx1], topics[idx2], errValg.GetInt("code"), errValg.GetStringBytes("message"))
-							recording = false
-						} else {
-							if err := compareResults(res.Result, resg.Result); err != nil {
-								fmt.Printf("Different logs for account %x %x %x and block %d-%d\n", account, topics[idx1], topics[idx2], prevBn, bn)
-								fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-								fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-								return
-							}
-						}
-					}
-					if recording {
-						fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-					}
-					log.Info("Results", "count", len(res.Result.GetArray("result")))
 				}
 			}
 		}
diff --git a/cmd/rpctest/rpctest/bench_traceblock.go b/cmd/rpctest/rpctest/bench_traceblock.go
index defd6b218..8752b3917 100644
--- a/cmd/rpctest/rpctest/bench_traceblock.go
+++ b/cmd/rpctest/rpctest/bench_traceblock.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -55,62 +66,17 @@ func BenchTraceBlock(erigonURL, oeURL string, needCompare bool, blockFrom uint64
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (OE) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (OE): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
 		reqGen.reqID++
 		request := reqGen.traceBlock(bn)
-		res = reqGen.Erigon2("trace_block", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace block (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing block (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_block", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_block", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace block (OE) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traces block %d, block %d: %v\n", bn, bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecall.go b/cmd/rpctest/rpctest/bench_tracecall.go
index fe05eb2d2..4caff26c7 100644
--- a/cmd/rpctest/rpctest/bench_tracecall.go
+++ b/cmd/rpctest/rpctest/bench_tracecall.go
@@ -32,7 +32,7 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 	var errs *bufio.Writer
 	if errorFile != "" {
 		ferr, err := os.Create(errorFile)
-		if ferr != nil {
+		if err != nil {
 			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
 			return
 		}
@@ -72,67 +72,13 @@ func BenchTraceCall(erigonURL, oeURL string, needCompare bool, blockFrom uint64,
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
 			reqGen.reqID++
 			request := reqGen.traceCall(tx.From, tx.To, &tx.Gas, &tx.GasPrice, &tx.Value, tx.Input, bn-1)
-			res = reqGen.Erigon2("trace_call", request)
-			if res.Err != nil {
-				fmt.Printf("Could not trace call (Erigon) %s: %v\n", tx.Hash, res.Err)
-				return
-			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_call", errCtx, reqGen, needCompare, rec, errs); err != nil {
 				return
 			}
-			if needCompare {
-				resg := reqGen.Geth2("trace_call", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace call (oe) %s: %v\n", tx.Hash, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-						if errs != nil {
-							fmt.Fprintf(errs, "Different traces block %d, tx %s: %v\n", bn, tx.Hash, err)
-							fmt.Fprintf(errs, "\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Fprintf(errs, "\n\nG response=================================\n%s\n", resg.Response)
-							errs.Flush() // nolint:errcheck
-							// Keep going
-						} else {
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracecallmany.go b/cmd/rpctest/rpctest/bench_tracecallmany.go
index be1d4d284..ab0133c8e 100644
--- a/cmd/rpctest/rpctest/bench_tracecallmany.go
+++ b/cmd/rpctest/rpctest/bench_tracecallmany.go
@@ -16,7 +16,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -32,6 +32,17 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -58,29 +69,11 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		n := len(b.Result.Transactions)
 		from := make([]common.Address, n)
 		to := make([]*common.Address, n)
@@ -101,38 +94,10 @@ func BenchTraceCallMany(erigonURL, oeURL string, needCompare bool, blockFrom uin
 		reqGen.reqID++
 
 		request := reqGen.traceCallMany(from, to, gas, gasPrice, value, data, bn-1)
-		recording := rec != nil // This flag will be set to false if recording is not to be performed
-		res = reqGen.Erigon2("trace_callMany", request)
-		if res.Err != nil {
-			fmt.Printf("Could not trace callMany (Erigon) %d: %v\n", bn, res.Err)
-			return
-		}
-		if errVal := res.Result.Get("error"); errVal != nil {
-			fmt.Printf("Error tracing call (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		errCtx := fmt.Sprintf("block %d", bn)
+		if err := requestAndCompare(request, "trace_callMany", errCtx, reqGen, needCompare, rec, errs); err != nil {
+			fmt.Println(err)
 			return
 		}
-		if needCompare {
-			resg := reqGen.Geth2("trace_callMany", request)
-			if resg.Err != nil {
-				fmt.Printf("Could not trace call (oe) %d: %v\n", bn, resg.Err)
-				return
-			}
-			if errVal := resg.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing call (oe): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-			if resg.Err == nil && resg.Result.Get("error") == nil {
-				recording = false
-				if err := compareResults(res.Result, resg.Result); err != nil {
-					fmt.Printf("Different traceManys block %d: %v\n", bn, err)
-					fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-					fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-					return
-				}
-			}
-		}
-		if recording {
-			fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracefilter.go b/cmd/rpctest/rpctest/bench_tracefilter.go
index 9028a20fb..26b116a68 100644
--- a/cmd/rpctest/rpctest/bench_tracefilter.go
+++ b/cmd/rpctest/rpctest/bench_tracefilter.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, oeURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -29,6 +29,17 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -64,73 +75,20 @@ func BenchTraceFilter(erigonURL, oeURL string, needCompare bool, blockFrom uint6
 		if res.Err == nil && mag.Error == nil {
 			accountSet := extractAccountMap(&mag)
 			for account := range accountSet {
-				recording := rec != nil // This flag will be set to false if recording is not to be performed
 				reqGen.reqID++
 				request := reqGen.traceFilterFrom(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter from (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter from (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx := fmt.Sprintf("traceFilterFrom fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, fromAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 				reqGen.reqID++
 				request = reqGen.traceFilterTo(prevBn, bn, account)
-				res = reqGen.Erigon2("trace_filter", request)
-				if res.Err != nil {
-					fmt.Printf("Could not trace filter to (Erigon) %d: %v\n", bn, res.Err)
-					return
-				}
-				if errVal := res.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing filter to (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
+				errCtx = fmt.Sprintf("traceFilterTo fromBlock %d, toBlock %d, fromAddress %x", prevBn, bn, account)
+				if err := requestAndCompare(request, "trace_filter", errCtx, reqGen, needCompare, rec, errs); err != nil {
+					fmt.Println(err)
 					return
 				}
-				if needCompare {
-					resg := reqGen.Geth2("trace_filter", request)
-					if resg.Err != nil {
-						fmt.Printf("Could not trace filter from (OE) %d: %v\n", bn, resg.Err)
-						return
-					}
-					if errVal := resg.Result.Get("error"); errVal != nil {
-						fmt.Printf("Error tracing filter from (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-						return
-					}
-					if resg.Err == nil && resg.Result.Get("error") == nil {
-						if err := compareResults(res.Result, resg.Result); err != nil {
-							fmt.Printf("Different traces fromBlock %d, toBlock %d, toAddress %x: %v\n", prevBn, bn, account, err)
-							fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-							fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-							return
-						}
-					}
-				}
-				if recording {
-					fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-				}
 			}
 		}
 		fmt.Printf("Done blocks %d-%d, modified accounts: %d\n", prevBn, bn, len(mag.Result))
diff --git a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
index a46dc76cb..f02488d4f 100644
--- a/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracereplaytransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,43 +57,12 @@ func BenchTraceReplayTransaction(erigonUrl, gethUrl string, needCompare bool, bl
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceReplayTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("trace_replayTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace replay transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "trace_replayTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing replay transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("trace_replayTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace replay transaction (OE) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing replay transaction (OE): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					recording = false
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different trace_replayTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nOE response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_tracetransaction.go b/cmd/rpctest/rpctest/bench_tracetransaction.go
index 0703911f7..83e9c14c2 100644
--- a/cmd/rpctest/rpctest/bench_tracetransaction.go
+++ b/cmd/rpctest/rpctest/bench_tracetransaction.go
@@ -8,7 +8,7 @@ import (
 	"time"
 )
 
-func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonUrl, gethUrl)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -25,6 +25,17 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -46,42 +57,12 @@ func BenchTraceTransaction(erigonUrl, gethUrl string, needCompare bool, blockFro
 		}
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.traceTransaction(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("debug_traceTransaction", request)
-
-			if res.Err != nil {
-				fmt.Printf("Could not trace transaction (Erigon) %s: %v\n", tx.Hash, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "debug_traceTransaction", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error tracing transaction (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("debug_traceTransaction", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not trace transaction (geth) %s: %v\n", tx.Hash, res.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error tracing transaction (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different traceTransaction block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/bench_txreceipts.go b/cmd/rpctest/rpctest/bench_txreceipts.go
index da47a90fd..14f635ded 100644
--- a/cmd/rpctest/rpctest/bench_txreceipts.go
+++ b/cmd/rpctest/rpctest/bench_txreceipts.go
@@ -13,7 +13,7 @@ import (
 // parameters:
 // needCompare - if false - doesn't call Erigon and doesn't compare responses
 // 		use false value - to generate vegeta files, it's faster but we can generate vegeta files for Geth and Erigon
-func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string) {
+func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint64, blockTo uint64, recordFile string, errorFile string) {
 	setRoutes(erigonURL, gethURL)
 	var client = &http.Client{
 		Timeout: time.Second * 600,
@@ -30,6 +30,17 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 		rec = bufio.NewWriter(f)
 		defer rec.Flush()
 	}
+	var errs *bufio.Writer
+	if errorFile != "" {
+		ferr, err := os.Create(errorFile)
+		if err != nil {
+			fmt.Printf("Cannot create file %s for error output: %v\n", errorFile, err)
+			return
+		}
+		defer ferr.Close()
+		errs = bufio.NewWriter(ferr)
+		defer errs.Flush()
+	}
 
 	var res CallResult
 	reqGen := &RequestGenerator{
@@ -56,66 +67,19 @@ func BenchTxReceipt(erigonURL, gethURL string, needCompare bool, blockFrom uint6
 			fmt.Printf("Could not retrieve block (Erigon) %d: %v\n", bn, res.Err)
 			return
 		}
-
 		if b.Error != nil {
 			fmt.Printf("Error retrieving block (Erigon): %d %s\n", b.Error.Code, b.Error.Message)
 			return
 		}
 
-		if needCompare {
-			var bg EthBlockByNumber
-			res = reqGen.Geth("eth_getBlockByNumber", reqGen.getBlockByNumber(bn), &bg)
-			if res.Err != nil {
-				fmt.Printf("Could not retrieve block (geth) %d: %v\n", bn, res.Err)
-				return
-			}
-			if bg.Error != nil {
-				fmt.Printf("Error retrieving block (geth): %d %s\n", bg.Error.Code, bg.Error.Message)
-				return
-			}
-			if !compareBlocks(&b, &bg) {
-				fmt.Printf("Block difference for %d\n", bn)
-				return
-			}
-		}
-
 		for _, tx := range b.Result.Transactions {
 			reqGen.reqID++
-
 			request := reqGen.getTransactionReceipt(tx.Hash)
-			recording := rec != nil // This flag will be set to false if recording is not to be performed
-			res = reqGen.Erigon2("eth_getTransactionReceipt", request)
-			if res.Err != nil {
-				fmt.Printf("Could not eth getTransactionReceipt (Erigon) %d: %v\n", bn, res.Err)
+			errCtx := fmt.Sprintf("block %d, tx %s", bn, tx.Hash)
+			if err := requestAndCompare(request, "eth_getTransactionReceipt", errCtx, reqGen, needCompare, rec, errs); err != nil {
+				fmt.Println(err)
 				return
 			}
-			if errVal := res.Result.Get("error"); errVal != nil {
-				fmt.Printf("Error eth getTransactionReceipt (Erigon): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-				return
-			}
-
-			if needCompare {
-				resg := reqGen.Geth2("eth_getTransactionReceipt", request)
-				if resg.Err != nil {
-					fmt.Printf("Could not eth getTransactionReceipt (geth) %d: %v\n", bn, resg.Err)
-					return
-				}
-				if errVal := resg.Result.Get("error"); errVal != nil {
-					fmt.Printf("Error eth getTransactionReceipt (geth): %d %s\n", errVal.GetInt("code"), errVal.GetStringBytes("message"))
-					return
-				}
-				if resg.Err == nil && resg.Result.Get("error") == nil {
-					if err := compareResults(res.Result, resg.Result); err != nil {
-						fmt.Printf("Different getTransactionReceipt block %d, tx %s: %v\n", bn, tx.Hash, err)
-						fmt.Printf("\n\nTG response=================================\n%s\n", res.Response)
-						fmt.Printf("\n\nG response=================================\n%s\n", resg.Response)
-						return
-					}
-				}
-			}
-			if recording {
-				fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
-			}
 		}
 	}
 }
diff --git a/cmd/rpctest/rpctest/utils.go b/cmd/rpctest/rpctest/utils.go
index e163c56d2..4f1b6e653 100644
--- a/cmd/rpctest/rpctest/utils.go
+++ b/cmd/rpctest/rpctest/utils.go
@@ -1,6 +1,7 @@
 package rpctest
 
 import (
+	"bufio"
 	"bytes"
 	"encoding/json"
 	"fmt"
@@ -183,6 +184,48 @@ func compareResults(trace, traceg *fastjson.Value) error {
 	return compareJsonValues("result", r, rg)
 }
 
+func requestAndCompare(request string, methodName string, errCtx string, reqGen *RequestGenerator, needCompare bool, rec *bufio.Writer, errs *bufio.Writer) error {
+	recording := rec != nil
+	res := reqGen.Erigon2(methodName, request)
+	if res.Err != nil {
+		return fmt.Errorf("could not invoke %s (Erigon): %w\n", methodName, res.Err)
+	}
+	if errVal := res.Result.Get("error"); errVal != nil {
+		return fmt.Errorf("error invoking %s (Erigon): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+	}
+	if needCompare {
+		resg := reqGen.Geth2(methodName, request)
+		if resg.Err != nil {
+			return fmt.Errorf("could not invoke %s (Geth/OE): %w\n", methodName, res.Err)
+		}
+		if errVal := resg.Result.Get("error"); errVal != nil {
+			return fmt.Errorf("error invoking %s (Geth/OE): %d %s\n", methodName, errVal.GetInt("code"), errVal.GetStringBytes("message"))
+		}
+		if resg.Err == nil && resg.Result.Get("error") == nil {
+			recording = false
+			if err := compareResults(res.Result, resg.Result); err != nil {
+				if errs != nil {
+					fmt.Printf("different results for method %s, errCtx: %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "\nDifferent results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+					fmt.Fprintf(errs, "Request=====================================\n%s\n", request)
+					fmt.Fprintf(errs, "TG response=================================\n%s\n", res.Response)
+					fmt.Fprintf(errs, "G/OE response=================================\n%s\n", resg.Response)
+					errs.Flush() // nolint:errcheck
+					// Keep going
+				} else {
+					fmt.Printf("TG response=================================\n%s\n", res.Response)
+					fmt.Printf("G response=================================\n%s\n", resg.Response)
+					return fmt.Errorf("different results for method %s, errCtx %s: %v\n", methodName, errCtx, err)
+				}
+			}
+		}
+	}
+	if recording {
+		fmt.Fprintf(rec, "%s\n%s\n\n", request, res.Response)
+	}
+	return nil
+}
+
 func compareBalances(balance, balanceg *EthBalance) bool {
 	if balance.Balance.ToInt().Cmp(balanceg.Balance.ToInt()) != 0 {
 		fmt.Printf("Different balance: %d %d\n", balance.Balance.ToInt(), balanceg.Balance.ToInt())
