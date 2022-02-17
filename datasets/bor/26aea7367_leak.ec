commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
commit 26aea736736dc70257b1c11676f626ab775e9339
Author: Janoš Guljaš <janos@users.noreply.github.com>
Date:   Thu Feb 7 11:40:36 2019 +0100

    cmd, node, p2p/simulations: fix node account manager leak (#19004)
    
    * node: close AccountsManager in new Close method
    
    * p2p/simulations, p2p/simulations/adapters: handle node close on shutdown
    
    * node: move node ephemeralKeystore cleanup to stop method
    
    * node: call Stop in Node.Close method
    
    * cmd/geth: close node.Node created with makeFullNode in cli commands
    
    * node: close Node instances in tests
    
    * cmd/geth, node: minor code style fixes
    
    * cmd, console, miner, mobile: proper node Close() termination

diff --git a/cmd/faucet/faucet.go b/cmd/faucet/faucet.go
index a7c20db77..5e4b77a6a 100644
--- a/cmd/faucet/faucet.go
+++ b/cmd/faucet/faucet.go
@@ -282,7 +282,7 @@ func newFaucet(genesis *core.Genesis, port int, enodes []*discv5.Node, network u
 
 // close terminates the Ethereum connection and tears down the faucet.
 func (f *faucet) close() error {
-	return f.stack.Stop()
+	return f.stack.Close()
 }
 
 // listenAndServe registers the HTTP handlers for the faucet and boots it up
diff --git a/cmd/geth/chaincmd.go b/cmd/geth/chaincmd.go
index 562c7e0de..6d41261f8 100644
--- a/cmd/geth/chaincmd.go
+++ b/cmd/geth/chaincmd.go
@@ -190,6 +190,8 @@ func initGenesis(ctx *cli.Context) error {
 	}
 	// Open an initialise both full and light databases
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	for _, name := range []string{"chaindata", "lightchaindata"} {
 		chaindb, err := stack.OpenDatabase(name, 0, 0)
 		if err != nil {
@@ -209,6 +211,8 @@ func importChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	defer chainDb.Close()
 
@@ -303,6 +307,8 @@ func exportChain(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, _ := utils.MakeChain(ctx, stack)
 	start := time.Now()
 
@@ -336,9 +342,11 @@ func importPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ImportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Import error: %v\n", err)
 	}
@@ -352,9 +360,11 @@ func exportPreimages(ctx *cli.Context) error {
 		utils.Fatalf("This command requires an argument.")
 	}
 	stack := makeFullNode(ctx)
-	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
+	defer stack.Close()
 
+	diskdb := utils.MakeChainDatabase(ctx, stack).(*ethdb.LDBDatabase)
 	start := time.Now()
+
 	if err := utils.ExportPreimages(diskdb, ctx.Args().First()); err != nil {
 		utils.Fatalf("Export error: %v\n", err)
 	}
@@ -369,8 +379,9 @@ func copyDb(ctx *cli.Context) error {
 	}
 	// Initialize a new chain for the running node to sync into
 	stack := makeFullNode(ctx)
-	chain, chainDb := utils.MakeChain(ctx, stack)
+	defer stack.Close()
 
+	chain, chainDb := utils.MakeChain(ctx, stack)
 	syncmode := *utils.GlobalTextMarshaler(ctx, utils.SyncModeFlag.Name).(*downloader.SyncMode)
 	dl := downloader.New(syncmode, chainDb, new(event.TypeMux), chain, nil, nil)
 
@@ -441,6 +452,8 @@ func removeDB(ctx *cli.Context) error {
 
 func dump(ctx *cli.Context) error {
 	stack := makeFullNode(ctx)
+	defer stack.Close()
+
 	chain, chainDb := utils.MakeChain(ctx, stack)
 	for _, arg := range ctx.Args() {
 		var block *types.Block
diff --git a/cmd/geth/consolecmd.go b/cmd/geth/consolecmd.go
index 2500a969c..d4443b328 100644
--- a/cmd/geth/consolecmd.go
+++ b/cmd/geth/consolecmd.go
@@ -79,7 +79,7 @@ func localConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
@@ -180,7 +180,7 @@ func ephemeralConsole(ctx *cli.Context) error {
 	// Create and start the node based on the CLI flags
 	node := makeFullNode(ctx)
 	startNode(ctx, node)
-	defer node.Stop()
+	defer node.Close()
 
 	// Attach to the newly started node and start the JavaScript console
 	client, err := node.Attach()
diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index dca02c82e..17bf438e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -279,6 +279,7 @@ func geth(ctx *cli.Context) error {
 		return fmt.Errorf("invalid command: %q", args[0])
 	}
 	node := makeFullNode(ctx)
+	defer node.Close()
 	startNode(ctx, node)
 	node.Wait()
 	return nil
diff --git a/cmd/swarm/main.go b/cmd/swarm/main.go
index 53888b615..11b51124d 100644
--- a/cmd/swarm/main.go
+++ b/cmd/swarm/main.go
@@ -288,6 +288,7 @@ func bzzd(ctx *cli.Context) error {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
 
 	//a few steps need to be done after the config phase is completed,
 	//due to overriding behavior
@@ -365,6 +366,8 @@ func getPrivKey(ctx *cli.Context) *ecdsa.PrivateKey {
 	if err != nil {
 		utils.Fatalf("can't create node: %v", err)
 	}
+	defer stack.Close()
+
 	return getAccount(bzzconfig.BzzAccount, ctx, stack)
 }
 
diff --git a/console/console_test.go b/console/console_test.go
index 26465ca6f..55d799725 100644
--- a/console/console_test.go
+++ b/console/console_test.go
@@ -149,8 +149,8 @@ func (env *tester) Close(t *testing.T) {
 	if err := env.console.Stop(false); err != nil {
 		t.Errorf("failed to stop embedded console: %v", err)
 	}
-	if err := env.stack.Stop(); err != nil {
-		t.Errorf("failed to stop embedded node: %v", err)
+	if err := env.stack.Close(); err != nil {
+		t.Errorf("failed to tear down embedded node: %v", err)
 	}
 	os.RemoveAll(env.workspace)
 }
diff --git a/miner/stress_clique.go b/miner/stress_clique.go
index 7e19975ae..8a355a4dc 100644
--- a/miner/stress_clique.go
+++ b/miner/stress_clique.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/miner/stress_ethash.go b/miner/stress_ethash.go
index 044ca9a21..040af9fba 100644
--- a/miner/stress_ethash.go
+++ b/miner/stress_ethash.go
@@ -69,7 +69,7 @@ func main() {
 		if err != nil {
 			panic(err)
 		}
-		defer node.Stop()
+		defer node.Close()
 
 		for node.Server().NodeInfo().Ports.Listener == 0 {
 			time.Sleep(250 * time.Millisecond)
diff --git a/mobile/geth.go b/mobile/geth.go
index 781f42f70..fba3e5711 100644
--- a/mobile/geth.go
+++ b/mobile/geth.go
@@ -192,6 +192,12 @@ func NewNode(datadir string, config *NodeConfig) (stack *Node, _ error) {
 	return &Node{rawStack}, nil
 }
 
+// Close terminates a running node along with all it's services, tearing internal
+// state doen too. It's not possible to restart a closed node.
+func (n *Node) Close() error {
+	return n.node.Close()
+}
+
 // Start creates a live P2P node and starts running it.
 func (n *Node) Start() error {
 	return n.node.Start()
diff --git a/node/config_test.go b/node/config_test.go
index b81d3d612..00c24a239 100644
--- a/node/config_test.go
+++ b/node/config_test.go
@@ -38,14 +38,22 @@ func TestDatadirCreation(t *testing.T) {
 	}
 	defer os.RemoveAll(dir)
 
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err := New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with existing datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	// Generate a long non-existing datadir path and check that it gets created by a node
 	dir = filepath.Join(dir, "a", "b", "c", "d", "e", "f")
-	if _, err := New(&Config{DataDir: dir}); err != nil {
+	node, err = New(&Config{DataDir: dir})
+	if err != nil {
 		t.Fatalf("failed to create stack with creatable datadir: %v", err)
 	}
+	if err := node.Close(); err != nil {
+		t.Fatalf("failed to close node: %v", err)
+	}
 	if _, err := os.Stat(dir); err != nil {
 		t.Fatalf("freshly created datadir not accessible: %v", err)
 	}
@@ -57,8 +65,12 @@ func TestDatadirCreation(t *testing.T) {
 	defer os.Remove(file.Name())
 
 	dir = filepath.Join(file.Name(), "invalid/path")
-	if _, err := New(&Config{DataDir: dir}); err == nil {
+	node, err = New(&Config{DataDir: dir})
+	if err == nil {
 		t.Fatalf("protocol stack created with an invalid datadir")
+		if err := node.Close(); err != nil {
+			t.Fatalf("failed to close node: %v", err)
+		}
 	}
 }
 
diff --git a/node/node.go b/node/node.go
index c35a50972..f267cdc46 100644
--- a/node/node.go
+++ b/node/node.go
@@ -121,6 +121,29 @@ func New(conf *Config) (*Node, error) {
 	}, nil
 }
 
+// Close stops the Node and releases resources acquired in
+// Node constructor New.
+func (n *Node) Close() error {
+	var errs []error
+
+	// Terminate all subsystems and collect any errors
+	if err := n.Stop(); err != nil && err != ErrNodeStopped {
+		errs = append(errs, err)
+	}
+	if err := n.accman.Close(); err != nil {
+		errs = append(errs, err)
+	}
+	// Report any errors that might have occurred
+	switch len(errs) {
+	case 0:
+		return nil
+	case 1:
+		return errs[0]
+	default:
+		return fmt.Errorf("%v", errs)
+	}
+}
+
 // Register injects a new service into the node's stack. The service created by
 // the passed constructor must be unique in its type with regard to sibling ones.
 func (n *Node) Register(constructor ServiceConstructor) error {
diff --git a/node/node_example_test.go b/node/node_example_test.go
index ee06f4065..57b18855f 100644
--- a/node/node_example_test.go
+++ b/node/node_example_test.go
@@ -46,6 +46,8 @@ func ExampleService() {
 	if err != nil {
 		log.Fatalf("Failed to create network node: %v", err)
 	}
+	defer stack.Close()
+
 	// Create and register a simple network service. This is done through the definition
 	// of a node.ServiceConstructor that will instantiate a node.Service. The reason for
 	// the factory method approach is to support service restarts without relying on the
diff --git a/node/node_test.go b/node/node_test.go
index f833cd688..c464771cd 100644
--- a/node/node_test.go
+++ b/node/node_test.go
@@ -46,6 +46,8 @@ func TestNodeLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Ensure that a stopped node can be stopped again
 	for i := 0; i < 3; i++ {
 		if err := stack.Stop(); err != ErrNodeStopped {
@@ -88,6 +90,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create original protocol stack: %v", err)
 	}
+	defer original.Close()
+
 	if err := original.Start(); err != nil {
 		t.Fatalf("failed to start original protocol stack: %v", err)
 	}
@@ -98,6 +102,8 @@ func TestNodeUsedDataDir(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create duplicate protocol stack: %v", err)
 	}
+	defer duplicate.Close()
+
 	if err := duplicate.Start(); err != ErrDatadirUsed {
 		t.Fatalf("duplicate datadir failure mismatch: have %v, want %v", err, ErrDatadirUsed)
 	}
@@ -109,6 +115,8 @@ func TestServiceRegistry(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of unique services and ensure they start successfully
 	services := []ServiceConstructor{NewNoopServiceA, NewNoopServiceB, NewNoopServiceC}
 	for i, constructor := range services {
@@ -141,6 +149,8 @@ func TestServiceLifeCycle(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of life-cycle instrumented services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -191,6 +201,8 @@ func TestServiceRestarts(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a service that does not support restarts
 	var (
 		running bool
@@ -239,6 +251,8 @@ func TestServiceConstructionAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Define a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -286,6 +300,8 @@ func TestServiceStartupAbortion(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -339,6 +355,8 @@ func TestServiceTerminationGuarantee(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of good services
 	services := map[string]InstrumentingWrapper{
 		"A": InstrumentedServiceMakerA,
@@ -414,6 +432,8 @@ func TestServiceRetrieval(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	if err := stack.Register(NewNoopService); err != nil {
 		t.Fatalf("noop service registration failed: %v", err)
 	}
@@ -449,6 +469,8 @@ func TestProtocolGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured number of protocols
 	services := map[string]struct {
 		Count int
@@ -505,6 +527,8 @@ func TestAPIGather(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
+
 	// Register a batch of services with some configured APIs
 	calls := make(chan string, 1)
 	makeAPI := func(result string) *OneMethodAPI {
diff --git a/node/service_test.go b/node/service_test.go
index a7ae439e0..73c51eccb 100644
--- a/node/service_test.go
+++ b/node/service_test.go
@@ -67,6 +67,7 @@ func TestContextServices(t *testing.T) {
 	if err != nil {
 		t.Fatalf("failed to create protocol stack: %v", err)
 	}
+	defer stack.Close()
 	// Define a verifier that ensures a NoopA is before it and NoopB after
 	verifier := func(ctx *ServiceContext) (Service, error) {
 		var objA *NoopServiceA
diff --git a/p2p/simulations/adapters/inproc.go b/p2p/simulations/adapters/inproc.go
index eada9579e..bdfbf1c73 100644
--- a/p2p/simulations/adapters/inproc.go
+++ b/p2p/simulations/adapters/inproc.go
@@ -172,6 +172,12 @@ type SimNode struct {
 	registerOnce sync.Once
 }
 
+// Close closes the underlaying node.Node to release
+// acquired resources.
+func (sn *SimNode) Close() error {
+	return sn.node.Close()
+}
+
 // Addr returns the node's discovery address
 func (sn *SimNode) Addr() []byte {
 	return []byte(sn.Node().String())
diff --git a/p2p/simulations/network.go b/p2p/simulations/network.go
index 6edcefc53..c2a3b9647 100644
--- a/p2p/simulations/network.go
+++ b/p2p/simulations/network.go
@@ -22,6 +22,7 @@ import (
 	"encoding/json"
 	"errors"
 	"fmt"
+	"io"
 	"math/rand"
 	"sync"
 	"time"
@@ -569,6 +570,12 @@ func (net *Network) Shutdown() {
 		if err := node.Stop(); err != nil {
 			log.Warn("Can't stop node", "id", node.ID(), "err", err)
 		}
+		// If the node has the close method, call it.
+		if closer, ok := node.Node.(io.Closer); ok {
+			if err := closer.Close(); err != nil {
+				log.Warn("Can't close node", "id", node.ID(), "err", err)
+			}
+		}
 	}
 	close(net.quitc)
 }
