commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
commit aba0c234c29c72860c369ec97553716a3fad11cd
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 30 14:43:20 2020 +0100

    cmd/geth: make tests run quicker + use less memory and disk (#21919)

diff --git a/cmd/geth/accountcmd_test.go b/cmd/geth/accountcmd_test.go
index 2f15915b0..e27adb691 100644
--- a/cmd/geth/accountcmd_test.go
+++ b/cmd/geth/accountcmd_test.go
@@ -43,13 +43,13 @@ func tmpDatadirWithKeystore(t *testing.T) string {
 }
 
 func TestAccountListEmpty(t *testing.T) {
-	geth := runGeth(t, "account", "list")
+	geth := runGeth(t, "--nousb", "account", "list")
 	geth.ExpectExit()
 }
 
 func TestAccountList(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "list", "--datadir", datadir)
+	geth := runGeth(t, "--nousb", "account", "list", "--datadir", datadir)
 	defer geth.ExpectExit()
 	if runtime.GOOS == "windows" {
 		geth.Expect(`
@@ -138,7 +138,7 @@ Fatal: Passwords do not match
 
 func TestAccountUpdate(t *testing.T) {
 	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t, "account", "update",
+	geth := runGeth(t, "--nousb", "account", "update",
 		"--datadir", datadir, "--lightkdf",
 		"f466859ead1932d743d622cb74fc058882e8648a")
 	defer geth.ExpectExit()
@@ -153,7 +153,7 @@ Repeat password: {{.InputLine "foobar2"}}
 }
 
 func TestWalletImport(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -168,7 +168,7 @@ Address: {d4584b5f6229b7be90727b0fc8c6b91bb427821f}
 }
 
 func TestWalletImportBadPassword(t *testing.T) {
-	geth := runGeth(t, "wallet", "import", "--lightkdf", "testdata/guswallet.json")
+	geth := runGeth(t, "--nousb", "wallet", "import", "--lightkdf", "testdata/guswallet.json")
 	defer geth.ExpectExit()
 	geth.Expect(`
 !! Unsupported terminal, password will be echoed.
@@ -178,11 +178,8 @@ Fatal: could not decrypt key with given password
 }
 
 func TestUnlockFlag(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "256", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -202,10 +199,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "js", "testdata/empty.js")
+
 	defer geth.ExpectExit()
 	geth.Expect(`
 Unlocking account f466859ead1932d743d622cb74fc058882e8648a | Attempt 1/3
@@ -221,10 +217,9 @@ Fatal: Failed to unlock account f466859ead1932d743d622cb74fc058882e8648a (could
 
 // https://github.com/ethereum/go-ethereum/issues/1785
 func TestUnlockFlagMultiIndex(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--unlock", "0,2", "js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.Expect(`
 Unlocking account 0 | Attempt 1/3
 !! Unsupported terminal, password will be echoed.
@@ -247,11 +242,9 @@ Password: {{.InputLine "foobar"}}
 }
 
 func TestUnlockFlagPasswordFile(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/passwords.txt", "--unlock", "0,2",
-		"js", "testdata/empty.js")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password", "testdata/passwords.txt", "--unlock", "0,2", "js", "testdata/empty.js")
+
 	geth.ExpectExit()
 
 	wantMessages := []string{
@@ -267,10 +260,9 @@ func TestUnlockFlagPasswordFile(t *testing.T) {
 }
 
 func TestUnlockFlagPasswordFileWrongPassword(t *testing.T) {
-	datadir := tmpDatadirWithKeystore(t)
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--datadir", datadir, "--password", "testdata/wrong-passwords.txt", "--unlock", "0,2")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--password",
+		"testdata/wrong-passwords.txt", "--unlock", "0,2")
 	defer geth.ExpectExit()
 	geth.Expect(`
 Fatal: Failed to unlock account 0 (could not decrypt key with given password)
@@ -279,9 +271,9 @@ Fatal: Failed to unlock account 0 (could not decrypt key with given password)
 
 func TestUnlockFlagAmbiguous(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a",
 		"js", "testdata/empty.js")
 	defer geth.ExpectExit()
 
@@ -317,9 +309,10 @@ In order to avoid this warning, you need to remove the following duplicate key f
 
 func TestUnlockFlagAmbiguousWrongPassword(t *testing.T) {
 	store := filepath.Join("..", "..", "accounts", "keystore", "testdata", "dupes")
-	geth := runGeth(t,
-		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--port", "0", "--nousb", "--cache", "128", "--ipcdisable",
-		"--keystore", store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+	geth := runMinimalGeth(t, "--port", "0", "--ipcdisable", "--datadir", tmpDatadirWithKeystore(t),
+		"--unlock", "f466859ead1932d743d622cb74fc058882e8648a", "--keystore",
+		store, "--unlock", "f466859ead1932d743d622cb74fc058882e8648a")
+
 	defer geth.ExpectExit()
 
 	// Helper for the expect template, returns absolute keystore path.
diff --git a/cmd/geth/consolecmd_test.go b/cmd/geth/consolecmd_test.go
index 913b06036..b0555c45d 100644
--- a/cmd/geth/consolecmd_test.go
+++ b/cmd/geth/consolecmd_test.go
@@ -35,16 +35,25 @@ const (
 	httpAPIs = "eth:1.0 net:1.0 rpc:1.0 web3:1.0"
 )
 
+// spawns geth with the given command line args, using a set of flags to minimise
+// memory and disk IO. If the args don't set --datadir, the
+// child g gets a temporary data directory.
+func runMinimalGeth(t *testing.T, args ...string) *testgeth {
+	// --ropsten to make the 'writing genesis to disk' faster (no accounts)
+	// --networkid=1337 to avoid cache bump
+	// --syncmode=full to avoid allocating fast sync bloom
+	allArgs := []string{"--ropsten", "--nousb", "--networkid", "1337", "--syncmode=full", "--port", "0",
+		"--nat", "none", "--nodiscover", "--maxpeers", "0", "--cache", "64"}
+	return runGeth(t, append(allArgs, args...)...)
+}
+
 // Tests that a node embedded within a console can be started up properly and
 // then terminated by closing the input stream.
 func TestConsoleWelcome(t *testing.T) {
 	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
 
 	// Start a geth console, make sure it's cleaned up and terminate the console
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase,
-		"console")
+	geth := runMinimalGeth(t, "--etherbase", coinbase, "console")
 
 	// Gather all the infos the welcome message needs to contain
 	geth.SetTemplateFunc("goos", func() string { return runtime.GOOS })
@@ -73,10 +82,13 @@ To exit, press ctrl-d
 }
 
 // Tests that a console can be attached to a running node via various means.
-func TestIPCAttachWelcome(t *testing.T) {
+func TestAttachWelcome(t *testing.T) {
+	var (
+		ipc      string
+		httpPort string
+		wsPort   string
+	)
 	// Configure the instance for IPC attachment
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	var ipc string
 	if runtime.GOOS == "windows" {
 		ipc = `\\.\pipe\geth` + strconv.Itoa(trulyRandInt(100000, 999999))
 	} else {
@@ -84,51 +96,28 @@ func TestIPCAttachWelcome(t *testing.T) {
 		defer os.RemoveAll(ws)
 		ipc = filepath.Join(ws, "geth.ipc")
 	}
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ipcpath", ipc)
-
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	waitForEndpoint(t, ipc, 3*time.Second)
-	testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
-
-}
-
-func TestHTTPAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--http", "--http.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "http://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
-}
-
-func TestWSAttachWelcome(t *testing.T) {
-	coinbase := "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182"
-	port := strconv.Itoa(trulyRandInt(1024, 65536)) // Yeah, sometimes this will fail, sorry :P
-
-	geth := runGeth(t,
-		"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none",
-		"--etherbase", coinbase, "--ws", "--ws.port", port)
-	defer func() {
-		geth.Interrupt()
-		geth.ExpectExit()
-	}()
-
-	endpoint := "ws://127.0.0.1:" + port
-	waitForEndpoint(t, endpoint, 3*time.Second)
-	testAttachWelcome(t, geth, endpoint, httpAPIs)
+	// And HTTP + WS attachment
+	p := trulyRandInt(1024, 65533) // Yeah, sometimes this will fail, sorry :P
+	httpPort = strconv.Itoa(p)
+	wsPort = strconv.Itoa(p + 1)
+	geth := runMinimalGeth(t, "--etherbase", "0x8605cdbbdb6d264aa742e77020dcbc58fcdce182",
+		"--ipcpath", ipc,
+		"--http", "--http.port", httpPort,
+		"--ws", "--ws.port", wsPort)
+	t.Run("ipc", func(t *testing.T) {
+		waitForEndpoint(t, ipc, 3*time.Second)
+		testAttachWelcome(t, geth, "ipc:"+ipc, ipcAPIs)
+	})
+	t.Run("http", func(t *testing.T) {
+		endpoint := "http://127.0.0.1:" + httpPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
+	t.Run("ws", func(t *testing.T) {
+		endpoint := "ws://127.0.0.1:" + wsPort
+		waitForEndpoint(t, endpoint, 3*time.Second)
+		testAttachWelcome(t, geth, endpoint, httpAPIs)
+	})
 }
 
 func testAttachWelcome(t *testing.T, geth *testgeth, endpoint, apis string) {
diff --git a/cmd/geth/dao_test.go b/cmd/geth/dao_test.go
index 6c36771e9..df7f14fdb 100644
--- a/cmd/geth/dao_test.go
+++ b/cmd/geth/dao_test.go
@@ -115,10 +115,10 @@ func testDAOForkBlockNewChain(t *testing.T, test int, genesis string, expectBloc
 		if err := ioutil.WriteFile(json, []byte(genesis), 0600); err != nil {
 			t.Fatalf("test %d: failed to write genesis file: %v", test, err)
 		}
-		runGeth(t, "--datadir", datadir, "init", json).WaitExit()
+		runGeth(t, "--datadir", datadir, "--nousb", "--networkid", "1337", "init", json).WaitExit()
 	} else {
 		// Force chain initialization
-		args := []string{"--port", "0", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
+		args := []string{"--port", "0", "--nousb", "--networkid", "1337", "--maxpeers", "0", "--nodiscover", "--nat", "none", "--ipcdisable", "--datadir", datadir}
 		runGeth(t, append(args, []string{"--exec", "2+2", "console"}...)...).WaitExit()
 	}
 	// Retrieve the DAO config flag from the database
diff --git a/cmd/geth/genesis_test.go b/cmd/geth/genesis_test.go
index ee3991acd..0651c32ca 100644
--- a/cmd/geth/genesis_test.go
+++ b/cmd/geth/genesis_test.go
@@ -84,7 +84,7 @@ func TestCustomGenesis(t *testing.T) {
 		runGeth(t, "--nousb", "--datadir", datadir, "init", json).WaitExit()
 
 		// Query the custom genesis block
-		geth := runGeth(t, "--nousb",
+		geth := runGeth(t, "--nousb", "--networkid", "1337", "--syncmode=full",
 			"--datadir", datadir, "--maxpeers", "0", "--port", "0",
 			"--nodiscover", "--nat", "none", "--ipcdisable",
 			"--exec", tt.query, "console")
diff --git a/cmd/geth/les_test.go b/cmd/geth/les_test.go
index e4fc2d4d0..d2f63ac7b 100644
--- a/cmd/geth/les_test.go
+++ b/cmd/geth/les_test.go
@@ -159,7 +159,7 @@ func initGeth(t *testing.T) string {
 func startLightServer(t *testing.T) *gethrpc {
 	datadir := initGeth(t)
 	t.Logf("Importing keys to geth")
-	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv").WaitExit()
+	runGeth(t, "--nousb", "--datadir", datadir, "--password", "./testdata/password.txt", "account", "import", "./testdata/key.prv", "--lightkdf").WaitExit()
 	account := "0x02f0d131f1f97aef08aec6e3291b957d9efe7105"
 	server := startGethWithIpc(t, "lightserver", "--allow-insecure-unlock", "--datadir", datadir, "--password", "./testdata/password.txt", "--unlock", account, "--mine", "--light.serve=100", "--light.maxpeers=1", "--nodiscover", "--nat=extip:127.0.0.1", "--verbosity=4")
 	return server
