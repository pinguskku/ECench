commit 26b50e3ebe3be197c68763e71e41926ed7df0863
Author: Ferenc Szabo <frncmx@gmail.com>
Date:   Thu Apr 11 12:44:15 2019 +0200

    cmd/swarm: fix resource leaks in tests (#19443)
    
    * swarm/api: fix file descriptor leak in NewTestSwarmServer
    
    Swarm storage (localstore) was not closed. That resulted a
    "too many open files" error if `TestClientUploadDownloadRawEncrypted`
    was run with `-count 1000`.
    
    * cmd/swarm: speed up StartNewNodes() by parallelization
    
    Reduce cluster startup time from 13s to 7s.
    
    * swarm/api: disable flaky TestClientUploadDownloadRawEncrypted with -race
    
    * swarm/storage: disable flaky TestLDBStoreCollectGarbage (-race)
    
    With race detection turned on the disabled cases often fail with:
    "ldbstore_test.go:535: expected surplus chunk 150 to be missing, but got no error"
    
    * cmd/swarm: fix process leak in TestACT and TestSwarmUp
    
    Each test run we start 3 nodes, but we did not terminate them. So
    those 3 nodes continued eating up 1.2GB (3.4GB with -race) after test
    completion.
    
    6b6c4d1c2754f8dd70172ab58d7ee33cf9058c7d changed how we start clusters
    to speed up tests. The changeset merged together test cases
    and introduced a global cluster. But "forgot" about termination.
    
    Let's get rid of "global cluster" so we have a clear owner of
    termination (some time sacrifice), while leaving subtests to use the
    same cluster.

diff --git a/cmd/swarm/access_test.go b/cmd/swarm/access_test.go
index 0898d33bc..0aaaad030 100644
--- a/cmd/swarm/access_test.go
+++ b/cmd/swarm/access_test.go
@@ -52,11 +52,12 @@ func TestACT(t *testing.T) {
 		t.Skip()
 	}
 
-	initCluster(t)
+	cluster := newTestCluster(t, clusterSize)
+	defer cluster.Shutdown()
 
 	cases := []struct {
 		name string
-		f    func(t *testing.T)
+		f    func(t *testing.T, cluster *testCluster)
 	}{
 		{"Password", testPassword},
 		{"PK", testPK},
@@ -65,7 +66,9 @@ func TestACT(t *testing.T) {
 	}
 
 	for _, tc := range cases {
-		t.Run(tc.name, tc.f)
+		t.Run(tc.name, func(t *testing.T) {
+			tc.f(t, cluster)
+		})
 	}
 }
 
@@ -74,7 +77,7 @@ func TestACT(t *testing.T) {
 // The parties participating - node (publisher), uploads to second node then disappears. Content which was uploaded
 // is then fetched through 2nd node. since the tested code is not key-aware - we can just
 // fetch from the 2nd node using HTTP BasicAuth
-func testPassword(t *testing.T) {
+func testPassword(t *testing.T, cluster *testCluster) {
 	dataFilename := testutil.TempFileWithContent(t, data)
 	defer os.RemoveAll(dataFilename)
 
@@ -226,7 +229,7 @@ func testPassword(t *testing.T) {
 // The parties participating - node (publisher), uploads to second node (which is also the grantee) then disappears.
 // Content which was uploaded is then fetched through the grantee's http proxy. Since the tested code is private-key aware,
 // the test will fail if the proxy's given private key is not granted on the ACT.
-func testPK(t *testing.T) {
+func testPK(t *testing.T, cluster *testCluster) {
 	dataFilename := testutil.TempFileWithContent(t, data)
 	defer os.RemoveAll(dataFilename)
 
@@ -359,13 +362,13 @@ func testPK(t *testing.T) {
 }
 
 // testACTWithoutBogus tests the creation of the ACT manifest end-to-end, without any bogus entries (i.e. default scenario = 3 nodes 1 unauthorized)
-func testACTWithoutBogus(t *testing.T) {
-	testACT(t, 0)
+func testACTWithoutBogus(t *testing.T, cluster *testCluster) {
+	testACT(t, cluster, 0)
 }
 
 // testACTWithBogus tests the creation of the ACT manifest end-to-end, with 100 bogus entries (i.e. 100 EC keys + default scenario = 3 nodes 1 unauthorized = 103 keys in the ACT manifest)
-func testACTWithBogus(t *testing.T) {
-	testACT(t, 100)
+func testACTWithBogus(t *testing.T, cluster *testCluster) {
+	testACT(t, cluster, 100)
 }
 
 // testACT tests the e2e creation, uploading and downloading of an ACT access control with both EC keys AND password protection
@@ -373,7 +376,7 @@ func testACTWithBogus(t *testing.T) {
 // set and also protects the ACT with a password. the third node should fail decoding the reference as it will not be granted access.
 // the third node then then tries to download using a correct password (and succeeds) then uses a wrong password and fails.
 // the publisher uploads through one of the nodes then disappears.
-func testACT(t *testing.T, bogusEntries int) {
+func testACT(t *testing.T, cluster *testCluster, bogusEntries int) {
 	var uploadThroughNode = cluster.Nodes[0]
 	client := swarmapi.NewClient(uploadThroughNode.URL)
 
diff --git a/cmd/swarm/run_test.go b/cmd/swarm/run_test.go
index 9681c8990..b68a1e897 100644
--- a/cmd/swarm/run_test.go
+++ b/cmd/swarm/run_test.go
@@ -59,15 +59,6 @@ func init() {
 
 const clusterSize = 3
 
-var clusteronce sync.Once
-var cluster *testCluster
-
-func initCluster(t *testing.T) {
-	clusteronce.Do(func() {
-		cluster = newTestCluster(t, clusterSize)
-	})
-}
-
 func serverFunc(api *api.API) swarmhttp.TestServer {
 	return swarmhttp.NewServer(api, "")
 }
@@ -165,10 +156,8 @@ outer:
 }
 
 func (c *testCluster) Shutdown() {
-	for _, node := range c.Nodes {
-		node.Shutdown()
-	}
-	os.RemoveAll(c.TmpDir)
+	c.Stop()
+	c.Cleanup()
 }
 
 func (c *testCluster) Stop() {
@@ -179,16 +168,35 @@ func (c *testCluster) Stop() {
 
 func (c *testCluster) StartNewNodes(t *testing.T, size int) {
 	c.Nodes = make([]*testNode, 0, size)
+
+	errors := make(chan error, size)
+	nodes := make(chan *testNode, size)
 	for i := 0; i < size; i++ {
-		dir := filepath.Join(c.TmpDir, fmt.Sprintf("swarm%02d", i))
-		if err := os.Mkdir(dir, 0700); err != nil {
-			t.Fatal(err)
-		}
+		go func(nodeIndex int) {
+			dir := filepath.Join(c.TmpDir, fmt.Sprintf("swarm%02d", nodeIndex))
+			if err := os.Mkdir(dir, 0700); err != nil {
+				errors <- err
+				return
+			}
 
-		node := newTestNode(t, dir)
-		node.Name = fmt.Sprintf("swarm%02d", i)
+			node := newTestNode(t, dir)
+			node.Name = fmt.Sprintf("swarm%02d", nodeIndex)
+			nodes <- node
+		}(i)
+	}
 
-		c.Nodes = append(c.Nodes, node)
+	for i := 0; i < size; i++ {
+		select {
+		case node := <-nodes:
+			c.Nodes = append(c.Nodes, node)
+		case err := <-errors:
+			t.Error(err)
+		}
+	}
+
+	if t.Failed() {
+		c.Shutdown()
+		t.FailNow()
 	}
 }
 
diff --git a/cmd/swarm/upload_test.go b/cmd/swarm/upload_test.go
index 616486e37..356424c66 100644
--- a/cmd/swarm/upload_test.go
+++ b/cmd/swarm/upload_test.go
@@ -46,11 +46,12 @@ func TestSwarmUp(t *testing.T) {
 		t.Skip()
 	}
 
-	initCluster(t)
+	cluster := newTestCluster(t, clusterSize)
+	defer cluster.Shutdown()
 
 	cases := []struct {
 		name string
-		f    func(t *testing.T)
+		f    func(t *testing.T, cluster *testCluster)
 	}{
 		{"NoEncryption", testNoEncryption},
 		{"Encrypted", testEncrypted},
@@ -60,31 +61,33 @@ func TestSwarmUp(t *testing.T) {
 	}
 
 	for _, tc := range cases {
-		t.Run(tc.name, tc.f)
+		t.Run(tc.name, func(t *testing.T) {
+			tc.f(t, cluster)
+		})
 	}
 }
 
 // testNoEncryption tests that running 'swarm up' makes the resulting file
 // available from all nodes via the HTTP API
-func testNoEncryption(t *testing.T) {
-	testDefault(false, t)
+func testNoEncryption(t *testing.T, cluster *testCluster) {
+	testDefault(t, cluster, false)
 }
 
 // testEncrypted tests that running 'swarm up --encrypted' makes the resulting file
 // available from all nodes via the HTTP API
-func testEncrypted(t *testing.T) {
-	testDefault(true, t)
+func testEncrypted(t *testing.T, cluster *testCluster) {
+	testDefault(t, cluster, true)
 }
 
-func testRecursiveNoEncryption(t *testing.T) {
-	testRecursive(false, t)
+func testRecursiveNoEncryption(t *testing.T, cluster *testCluster) {
+	testRecursive(t, cluster, false)
 }
 
-func testRecursiveEncrypted(t *testing.T) {
-	testRecursive(true, t)
+func testRecursiveEncrypted(t *testing.T, cluster *testCluster) {
+	testRecursive(t, cluster, true)
 }
 
-func testDefault(toEncrypt bool, t *testing.T) {
+func testDefault(t *testing.T, cluster *testCluster, toEncrypt bool) {
 	tmpFileName := testutil.TempFileWithContent(t, data)
 	defer os.Remove(tmpFileName)
 
@@ -189,7 +192,7 @@ func testDefault(toEncrypt bool, t *testing.T) {
 	}
 }
 
-func testRecursive(toEncrypt bool, t *testing.T) {
+func testRecursive(t *testing.T, cluster *testCluster, toEncrypt bool) {
 	tmpUploadDir, err := ioutil.TempDir("", "swarm-test")
 	if err != nil {
 		t.Fatal(err)
@@ -279,14 +282,14 @@ func testRecursive(toEncrypt bool, t *testing.T) {
 
 // testDefaultPathAll tests swarm recursive upload with relative and absolute
 // default paths and with encryption.
-func testDefaultPathAll(t *testing.T) {
-	testDefaultPath(false, false, t)
-	testDefaultPath(false, true, t)
-	testDefaultPath(true, false, t)
-	testDefaultPath(true, true, t)
+func testDefaultPathAll(t *testing.T, cluster *testCluster) {
+	testDefaultPath(t, cluster, false, false)
+	testDefaultPath(t, cluster, false, true)
+	testDefaultPath(t, cluster, true, false)
+	testDefaultPath(t, cluster, true, true)
 }
 
-func testDefaultPath(toEncrypt bool, absDefaultPath bool, t *testing.T) {
+func testDefaultPath(t *testing.T, cluster *testCluster, toEncrypt bool, absDefaultPath bool) {
 	tmp, err := ioutil.TempDir("", "swarm-defaultpath-test")
 	if err != nil {
 		t.Fatal(err)
diff --git a/swarm/api/client/client_test.go b/swarm/api/client/client_test.go
index 39f6e4797..9c9bde5d6 100644
--- a/swarm/api/client/client_test.go
+++ b/swarm/api/client/client_test.go
@@ -25,6 +25,8 @@ import (
 	"sort"
 	"testing"
 
+	"github.com/ethereum/go-ethereum/swarm/testutil"
+
 	"github.com/ethereum/go-ethereum/swarm/storage"
 	"github.com/ethereum/go-ethereum/swarm/storage/feed/lookup"
 
@@ -43,7 +45,13 @@ func serverFunc(api *api.API) swarmhttp.TestServer {
 func TestClientUploadDownloadRaw(t *testing.T) {
 	testClientUploadDownloadRaw(false, t)
 }
+
 func TestClientUploadDownloadRawEncrypted(t *testing.T) {
+	if testutil.RaceEnabled {
+		t.Skip("flaky with -race on Travis")
+		// See: https://github.com/ethersphere/go-ethereum/issues/1254
+	}
+
 	testClientUploadDownloadRaw(true, t)
 }
 
diff --git a/swarm/api/http/test_server.go b/swarm/api/http/test_server.go
index 9245c9c5b..97fdf0d8a 100644
--- a/swarm/api/http/test_server.go
+++ b/swarm/api/http/test_server.go
@@ -33,44 +33,45 @@ type TestServer interface {
 }
 
 func NewTestSwarmServer(t *testing.T, serverFunc func(*api.API) TestServer, resolver api.Resolver) *TestSwarmServer {
-	dir, err := ioutil.TempDir("", "swarm-storage-test")
+	swarmDir, err := ioutil.TempDir("", "swarm-storage-test")
 	if err != nil {
 		t.Fatal(err)
 	}
-	storeparams := storage.NewDefaultLocalStoreParams()
-	storeparams.DbCapacity = 5000000
-	storeparams.CacheCapacity = 5000
-	storeparams.Init(dir)
-	localStore, err := storage.NewLocalStore(storeparams, nil)
+
+	storeParams := storage.NewDefaultLocalStoreParams()
+	storeParams.DbCapacity = 5000000
+	storeParams.CacheCapacity = 5000
+	storeParams.Init(swarmDir)
+	localStore, err := storage.NewLocalStore(storeParams, nil)
 	if err != nil {
-		os.RemoveAll(dir)
+		os.RemoveAll(swarmDir)
 		t.Fatal(err)
 	}
 	fileStore := storage.NewFileStore(localStore, storage.NewFileStoreParams())
-
 	// Swarm feeds test setup
 	feedsDir, err := ioutil.TempDir("", "swarm-feeds-test")
 	if err != nil {
 		t.Fatal(err)
 	}
 
-	rhparams := &feed.HandlerParams{}
-	rh, err := feed.NewTestHandler(feedsDir, rhparams)
+	feeds, err := feed.NewTestHandler(feedsDir, &feed.HandlerParams{})
 	if err != nil {
 		t.Fatal(err)
 	}
 
-	a := api.NewAPI(fileStore, resolver, rh.Handler, nil)
-	srv := httptest.NewServer(serverFunc(a))
+	swarmApi := api.NewAPI(fileStore, resolver, feeds.Handler, nil)
+	apiServer := httptest.NewServer(serverFunc(swarmApi))
+
 	tss := &TestSwarmServer{
-		Server:    srv,
+		Server:    apiServer,
 		FileStore: fileStore,
-		dir:       dir,
+		dir:       swarmDir,
 		Hasher:    storage.MakeHashFunc(storage.DefaultHash)(),
 		cleanup: func() {
-			srv.Close()
-			rh.Close()
-			os.RemoveAll(dir)
+			apiServer.Close()
+			fileStore.Close()
+			feeds.Close()
+			os.RemoveAll(swarmDir)
 			os.RemoveAll(feedsDir)
 		},
 		CurrentTime: 42,
diff --git a/swarm/storage/ldbstore_test.go b/swarm/storage/ldbstore_test.go
index d17bd7d0e..70b0d6bb4 100644
--- a/swarm/storage/ldbstore_test.go
+++ b/swarm/storage/ldbstore_test.go
@@ -27,6 +27,8 @@ import (
 	"strings"
 	"testing"
 
+	"github.com/ethereum/go-ethereum/swarm/testutil"
+
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/swarm/chunk"
 	"github.com/ethereum/go-ethereum/swarm/log"
@@ -322,6 +324,12 @@ func TestLDBStoreCollectGarbage(t *testing.T) {
 	initialCap := defaultMaxGCRound / 100
 	cap := initialCap / 2
 	t.Run(fmt.Sprintf("A/%d/%d", cap, cap*4), testLDBStoreCollectGarbage)
+
+	if testutil.RaceEnabled {
+		t.Skip("only the simplest case run as others are flaky with race")
+		// Note: some tests fail consistently and even locally with `-race`
+	}
+
 	t.Run(fmt.Sprintf("B/%d/%d", cap, cap*4), testLDBStoreRemoveThenCollectGarbage)
 
 	// at max round
