commit be6078ad831dea01121510dfc9ab1f264a3a189c
Author: Boqin Qin <Bobbqqin@gmail.com>
Date:   Sat Apr 4 02:07:22 2020 +0800

    all: fix a bunch of inconsequential goroutine leaks (#20667)
    
    The leaks were mostly in unit tests, and could all be resolved by
    adding suitably-sized channel buffers or by restructuring the test
    to not send on a channel after an error has occurred.
    
    There is an unavoidable goroutine leak in Console.Interactive: when
    we receive a signal, the line reader cannot be unblocked and will get
    stuck. This leak is now documented and I've tried to make it slightly
    less bad by adding a one-element buffer to the output channels of
    the line-reading loop. Should the reader eventually awake from its
    blocked state (i.e. when stdin is closed), at least it won't get stuck
    trying to send to the interpreter loop which has quit long ago.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/prque/lazyqueue_test.go b/common/prque/lazyqueue_test.go
index 0bd4fc659..be9491e24 100644
--- a/common/prque/lazyqueue_test.go
+++ b/common/prque/lazyqueue_test.go
@@ -74,17 +74,22 @@ func TestLazyQueue(t *testing.T) {
 		q.Push(&items[i])
 	}
 
-	var lock sync.Mutex
-	stopCh := make(chan chan struct{})
+	var (
+		lock   sync.Mutex
+		wg     sync.WaitGroup
+		stopCh = make(chan chan struct{})
+	)
+	defer wg.Wait()
+	wg.Add(1)
 	go func() {
+		defer wg.Done()
 		for {
 			select {
 			case <-clock.After(testQueueRefresh):
 				lock.Lock()
 				q.Refresh()
 				lock.Unlock()
-			case stop := <-stopCh:
-				close(stop)
+			case <-stopCh:
 				return
 			}
 		}
@@ -104,6 +109,8 @@ func TestLazyQueue(t *testing.T) {
 		if rand.Intn(100) == 0 {
 			p := q.PopItem().(*lazyItem)
 			if p.p != maxPri {
+				lock.Unlock()
+				close(stopCh)
 				t.Fatalf("incorrect item (best known priority %d, popped %d)", maxPri, p.p)
 			}
 			q.Push(p)
@@ -113,7 +120,5 @@ func TestLazyQueue(t *testing.T) {
 		clock.WaitForTimers(1)
 	}
 
-	stop := make(chan struct{})
-	stopCh <- stop
-	<-stop
+	close(stopCh)
 }
diff --git a/console/console.go b/console/console.go
index a2f12d8ed..e2b4835e4 100644
--- a/console/console.go
+++ b/console/console.go
@@ -340,62 +340,61 @@ func (c *Console) Evaluate(statement string) {
 // the configured user prompter.
 func (c *Console) Interactive() {
 	var (
-		prompt    = c.prompt          // Current prompt line (used for multi-line inputs)
-		indents   = 0                 // Current number of input indents (used for multi-line inputs)
-		input     = ""                // Current user input
-		scheduler = make(chan string) // Channel to send the next prompt on and receive the input
+		prompt      = c.prompt             // the current prompt line (used for multi-line inputs)
+		indents     = 0                    // the current number of input indents (used for multi-line inputs)
+		input       = ""                   // the current user input
+		inputLine   = make(chan string, 1) // receives user input
+		inputErr    = make(chan error, 1)  // receives liner errors
+		requestLine = make(chan string)    // requests a line of input
+		interrupt   = make(chan os.Signal, 1)
 	)
-	// Start a goroutine to listen for prompt requests and send back inputs
-	go func() {
-		for {
-			// Read the next user input
-			line, err := c.prompter.PromptInput(<-scheduler)
-			if err != nil {
-				// In case of an error, either clear the prompt or fail
-				if err == liner.ErrPromptAborted { // ctrl-C
-					prompt, indents, input = c.prompt, 0, ""
-					scheduler <- ""
-					continue
-				}
-				close(scheduler)
-				return
-			}
-			// User input retrieved, send for interpretation and loop
-			scheduler <- line
-		}
-	}()
-	// Monitor Ctrl-C too in case the input is empty and we need to bail
-	abort := make(chan os.Signal, 1)
-	signal.Notify(abort, syscall.SIGINT, syscall.SIGTERM)
 
-	// Start sending prompts to the user and reading back inputs
+	// Monitor Ctrl-C. While liner does turn on the relevant terminal mode bits to avoid
+	// the signal, a signal can still be received for unsupported terminals. Unfortunately
+	// there is no way to cancel the line reader when this happens. The readLines
+	// goroutine will be leaked in this case.
+	signal.Notify(interrupt, syscall.SIGINT, syscall.SIGTERM)
+	defer signal.Stop(interrupt)
+
+	// The line reader runs in a separate goroutine.
+	go c.readLines(inputLine, inputErr, requestLine)
+	defer close(requestLine)
+
 	for {
-		// Send the next prompt, triggering an input read and process the result
-		scheduler <- prompt
+		// Send the next prompt, triggering an input read.
+		requestLine <- prompt
+
 		select {
-		case <-abort:
-			// User forcefully quite the console
+		case <-interrupt:
 			fmt.Fprintln(c.printer, "caught interrupt, exiting")
 			return
 
-		case line, ok := <-scheduler:
-			// User input was returned by the prompter, handle special cases
-			if !ok || (indents <= 0 && exit.MatchString(line)) {
+		case err := <-inputErr:
+			if err == liner.ErrPromptAborted && indents > 0 {
+				// When prompting for multi-line input, the first Ctrl-C resets
+				// the multi-line state.
+				prompt, indents, input = c.prompt, 0, ""
+				continue
+			}
+			return
+
+		case line := <-inputLine:
+			// User input was returned by the prompter, handle special cases.
+			if indents <= 0 && exit.MatchString(line) {
 				return
 			}
 			if onlyWhitespace.MatchString(line) {
 				continue
 			}
-			// Append the line to the input and check for multi-line interpretation
+			// Append the line to the input and check for multi-line interpretation.
 			input += line + "\n"
-
 			indents = countIndents(input)
 			if indents <= 0 {
 				prompt = c.prompt
 			} else {
 				prompt = strings.Repeat(".", indents*3) + " "
 			}
-			// If all the needed lines are present, save the command and run
+			// If all the needed lines are present, save the command and run it.
 			if indents <= 0 {
 				if len(input) > 0 && input[0] != ' ' && !passwordRegexp.MatchString(input) {
 					if command := strings.TrimSpace(input); len(c.history) == 0 || command != c.history[len(c.history)-1] {
@@ -412,6 +411,18 @@ func (c *Console) Interactive() {
 	}
 }
 
+// readLines runs in its own goroutine, prompting for input.
+func (c *Console) readLines(input chan<- string, errc chan<- error, prompt <-chan string) {
+	for p := range prompt {
+		line, err := c.prompter.PromptInput(p)
+		if err != nil {
+			errc <- err
+		} else {
+			input <- line
+		}
+	}
+}
+
 // countIndents returns the number of identations for the given input.
 // In case of invalid input such as var a = } the result can be negative.
 func countIndents(input string) int {
diff --git a/event/event_test.go b/event/event_test.go
index 2be357ba2..cc9fa5d7c 100644
--- a/event/event_test.go
+++ b/event/event_test.go
@@ -203,6 +203,7 @@ func BenchmarkPostConcurrent(b *testing.B) {
 // for comparison
 func BenchmarkChanSend(b *testing.B) {
 	c := make(chan interface{})
+	defer close(c)
 	closed := make(chan struct{})
 	go func() {
 		for range c {
diff --git a/miner/worker_test.go b/miner/worker_test.go
index 78e09a176..86bb7db64 100644
--- a/miner/worker_test.go
+++ b/miner/worker_test.go
@@ -17,7 +17,6 @@
 package miner
 
 import (
-	"fmt"
 	"math/big"
 	"math/rand"
 	"sync/atomic"
@@ -210,49 +209,37 @@ func testGenerateBlockAndImport(t *testing.T, isClique bool) {
 	w, b := newTestWorker(t, chainConfig, engine, db, 0)
 	defer w.close()
 
+	// This test chain imports the mined blocks.
 	db2 := rawdb.NewMemoryDatabase()
 	b.genesis.MustCommit(db2)
 	chain, _ := core.NewBlockChain(db2, nil, b.chain.Config(), engine, vm.Config{}, nil)
 	defer chain.Stop()
 
-	var (
-		loopErr   = make(chan error)
-		newBlock  = make(chan struct{})
-		subscribe = make(chan struct{})
-	)
-	listenNewBlock := func() {
-		sub := w.mux.Subscribe(core.NewMinedBlockEvent{})
-		defer sub.Unsubscribe()
-
-		subscribe <- struct{}{}
-		for item := range sub.Chan() {
-			block := item.Data.(core.NewMinedBlockEvent).Block
-			_, err := chain.InsertChain([]*types.Block{block})
-			if err != nil {
-				loopErr <- fmt.Errorf("failed to insert new mined block:%d, error:%v", block.NumberU64(), err)
-			}
-			newBlock <- struct{}{}
-		}
-	}
