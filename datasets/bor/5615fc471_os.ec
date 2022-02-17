commit 5615fc47149ea5db6ad6f5b1b716e5af9900f848
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 15:01:13 2015 +0200

    cmd/geth, cmd/utils: improve interrupt handling
    
    The new strategy for interrupts is to handle them explicitly.
    Ethereum.Stop is now only called once, even if multiple interrupts
    are sent. Interrupting ten times in a row forces a panic.
    
    Fixes #869
    Fixes #1359

diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index ffd26a7c2..3428bb4cf 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -347,7 +347,6 @@ func main() {
 }
 
 func run(ctx *cli.Context) {
-	utils.HandleInterrupt()
 	cfg := utils.MakeEthConfig(ClientIdentifier, nodeNameVersion, ctx)
 	ethereum, err := eth.New(cfg)
 	if err != nil {
@@ -527,10 +526,9 @@ func blockRecovery(ctx *cli.Context) {
 
 func startEth(ctx *cli.Context, eth *eth.Ethereum) {
 	// Start Ethereum itself
-
 	utils.StartEthereum(eth)
-	am := eth.AccountManager()
 
+	am := eth.AccountManager()
 	account := ctx.GlobalString(utils.UnlockedAccountFlag.Name)
 	accounts := strings.Split(account, " ")
 	for i, account := range accounts {
diff --git a/cmd/utils/cmd.go b/cmd/utils/cmd.go
index f7520a8e4..33a6c1cb2 100644
--- a/cmd/utils/cmd.go
+++ b/cmd/utils/cmd.go
@@ -46,29 +46,6 @@ const (
 
 var interruptCallbacks = []func(os.Signal){}
 
-// Register interrupt handlers callbacks
-func RegisterInterrupt(cb func(os.Signal)) {
-	interruptCallbacks = append(interruptCallbacks, cb)
-}
-
-// go routine that call interrupt handlers in order of registering
-func HandleInterrupt() {
-	c := make(chan os.Signal, 1)
-	go func() {
-		signal.Notify(c, os.Interrupt)
-		for sig := range c {
-			glog.V(logger.Error).Infof("Shutting down (%v) ... \n", sig)
-			RunInterruptCallbacks(sig)
-		}
-	}()
-}
-
-func RunInterruptCallbacks(sig os.Signal) {
-	for _, cb := range interruptCallbacks {
-		cb(sig)
-	}
-}
-
 func openLogFile(Datadir string, filename string) *os.File {
 	path := common.AbsolutePath(Datadir, filename)
 	file, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
@@ -149,19 +126,24 @@ func StartEthereum(ethereum *eth.Ethereum) {
 	if err := ethereum.Start(); err != nil {
 		Fatalf("Error starting Ethereum: %v", err)
 	}
-	RegisterInterrupt(func(sig os.Signal) {
-		ethereum.Stop()
-		logger.Flush()
-	})
-}
-
-func StartEthereumForTest(ethereum *eth.Ethereum) {
-	glog.V(logger.Info).Infoln("Starting ", ethereum.Name())
-	ethereum.StartForTest()
-	RegisterInterrupt(func(sig os.Signal) {
+	go func() {
+		sigc := make(chan os.Signal, 1)
+		signal.Notify(sigc, os.Interrupt)
+		defer signal.Stop(sigc)
+		<-sigc
+		glog.V(logger.Info).Infoln("Got interrupt, shutting down...")
 		ethereum.Stop()
 		logger.Flush()
-	})
+		for i := 10; i > 0; i-- {
+			<-sigc
+			if i > 1 {
+				glog.V(logger.Info).Infoln("Already shutting down, please be patient.")
+				glog.V(logger.Info).Infoln("Interrupt", i-1, "more times to induce panic.")
+			}
+		}
+		glog.V(logger.Error).Infof("Force quitting: this might not end so well.")
+		panic("boom")
+	}()
 }
 
 func FormatTransactionData(data string) []byte {
commit 5615fc47149ea5db6ad6f5b1b716e5af9900f848
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 15:01:13 2015 +0200

    cmd/geth, cmd/utils: improve interrupt handling
    
    The new strategy for interrupts is to handle them explicitly.
    Ethereum.Stop is now only called once, even if multiple interrupts
    are sent. Interrupting ten times in a row forces a panic.
    
    Fixes #869
    Fixes #1359

diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index ffd26a7c2..3428bb4cf 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -347,7 +347,6 @@ func main() {
 }
 
 func run(ctx *cli.Context) {
-	utils.HandleInterrupt()
 	cfg := utils.MakeEthConfig(ClientIdentifier, nodeNameVersion, ctx)
 	ethereum, err := eth.New(cfg)
 	if err != nil {
@@ -527,10 +526,9 @@ func blockRecovery(ctx *cli.Context) {
 
 func startEth(ctx *cli.Context, eth *eth.Ethereum) {
 	// Start Ethereum itself
-
 	utils.StartEthereum(eth)
-	am := eth.AccountManager()
 
+	am := eth.AccountManager()
 	account := ctx.GlobalString(utils.UnlockedAccountFlag.Name)
 	accounts := strings.Split(account, " ")
 	for i, account := range accounts {
diff --git a/cmd/utils/cmd.go b/cmd/utils/cmd.go
index f7520a8e4..33a6c1cb2 100644
--- a/cmd/utils/cmd.go
+++ b/cmd/utils/cmd.go
@@ -46,29 +46,6 @@ const (
 
 var interruptCallbacks = []func(os.Signal){}
 
-// Register interrupt handlers callbacks
-func RegisterInterrupt(cb func(os.Signal)) {
-	interruptCallbacks = append(interruptCallbacks, cb)
-}
-
-// go routine that call interrupt handlers in order of registering
-func HandleInterrupt() {
-	c := make(chan os.Signal, 1)
-	go func() {
-		signal.Notify(c, os.Interrupt)
-		for sig := range c {
-			glog.V(logger.Error).Infof("Shutting down (%v) ... \n", sig)
-			RunInterruptCallbacks(sig)
-		}
-	}()
-}
-
-func RunInterruptCallbacks(sig os.Signal) {
-	for _, cb := range interruptCallbacks {
-		cb(sig)
-	}
-}
-
 func openLogFile(Datadir string, filename string) *os.File {
 	path := common.AbsolutePath(Datadir, filename)
 	file, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
@@ -149,19 +126,24 @@ func StartEthereum(ethereum *eth.Ethereum) {
 	if err := ethereum.Start(); err != nil {
 		Fatalf("Error starting Ethereum: %v", err)
 	}
-	RegisterInterrupt(func(sig os.Signal) {
-		ethereum.Stop()
-		logger.Flush()
-	})
-}
-
-func StartEthereumForTest(ethereum *eth.Ethereum) {
-	glog.V(logger.Info).Infoln("Starting ", ethereum.Name())
-	ethereum.StartForTest()
-	RegisterInterrupt(func(sig os.Signal) {
+	go func() {
+		sigc := make(chan os.Signal, 1)
+		signal.Notify(sigc, os.Interrupt)
+		defer signal.Stop(sigc)
+		<-sigc
+		glog.V(logger.Info).Infoln("Got interrupt, shutting down...")
 		ethereum.Stop()
 		logger.Flush()
-	})
+		for i := 10; i > 0; i-- {
+			<-sigc
+			if i > 1 {
+				glog.V(logger.Info).Infoln("Already shutting down, please be patient.")
+				glog.V(logger.Info).Infoln("Interrupt", i-1, "more times to induce panic.")
+			}
+		}
+		glog.V(logger.Error).Infof("Force quitting: this might not end so well.")
+		panic("boom")
+	}()
 }
 
 func FormatTransactionData(data string) []byte {
