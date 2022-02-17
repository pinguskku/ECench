commit 4800c94392e814a2cb9d343aab4706be0cd0851d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed May 6 15:32:53 2015 +0300

    eth/downloader: prioritize block fetch based on chain position, cap memory use

diff --git a/Godeps/Godeps.json b/Godeps/Godeps.json
index 2480ff9a2..a5b27e76c 100644
--- a/Godeps/Godeps.json
+++ b/Godeps/Godeps.json
@@ -98,6 +98,10 @@
 			"Comment": "v0.1.0-3-g27c4092",
 			"Rev": "27c40922c40b43fe04554d8223a402af3ea333f3"
 		},
+		{
+			"ImportPath": "gopkg.in/karalabe/cookiejar.v2/collections/prque",
+			"Rev": "cf5d8079df7c4501217638e1e3a6e43f94822548"
+		},
 		{
 			"ImportPath": "gopkg.in/qml.v1/cdata",
 			"Rev": "1116cb9cd8dee23f8d444ded354eb53122739f99"
diff --git a/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/example_test.go b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/example_test.go
new file mode 100644
index 000000000..7b2e5ee84
--- /dev/null
+++ b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/example_test.go
@@ -0,0 +1,44 @@
+// CookieJar - A contestant's algorithm toolbox
+// Copyright (c) 2013 Peter Szilagyi. All rights reserved.
+//
+// CookieJar is dual licensed: you can redistribute it and/or modify it under
+// the terms of the GNU General Public License as published by the Free Software
+// Foundation, either version 3 of the License, or (at your option) any later
+// version.
+//
+// The toolbox is distributed in the hope that it will be useful, but WITHOUT
+// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
+// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
+// more details.
+//
+// Alternatively, the CookieJar toolbox may be used in accordance with the terms
+// and conditions contained in a signed written agreement between you and the
+// author(s).
+
+package prque_test
+
+import (
+	"fmt"
+
+	"gopkg.in/karalabe/cookiejar.v2/collections/prque"
+)
+
+// Insert some data into a priority queue and pop them out in prioritized order.
+func Example_usage() {
+	// Define some data to push into the priority queue
+	prio := []float32{77.7, 22.2, 44.4, 55.5, 11.1, 88.8, 33.3, 99.9, 0.0, 66.6}
+	data := []string{"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"}
+
+	// Create the priority queue and insert the prioritized data
+	pq := prque.New()
+	for i := 0; i < len(data); i++ {
+		pq.Push(data[i], prio[i])
+	}
+	// Pop out the data and print them
+	for !pq.Empty() {
+		val, prio := pq.Pop()
+		fmt.Printf("%.1f:%s ", prio, val)
+	}
+	// Output:
+	// 99.9:seven 88.8:five 77.7:zero 66.6:nine 55.5:three 44.4:two 33.3:six 22.2:one 11.1:four 0.0:eight
+}
diff --git a/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/prque.go b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/prque.go
new file mode 100644
index 000000000..8225e8c53
--- /dev/null
+++ b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/prque.go
@@ -0,0 +1,75 @@
+// CookieJar - A contestant's algorithm toolbox
+// Copyright (c) 2013 Peter Szilagyi. All rights reserved.
+//
+// CookieJar is dual licensed: you can redistribute it and/or modify it under
+// the terms of the GNU General Public License as published by the Free Software
+// Foundation, either version 3 of the License, or (at your option) any later
+// version.
+//
+// The toolbox is distributed in the hope that it will be useful, but WITHOUT
+// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
+// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
+// more details.
+//
+// Alternatively, the CookieJar toolbox may be used in accordance with the terms
+// and conditions contained in a signed written agreement between you and the
+// author(s).
+
+// Package prque implements a priority queue data structure supporting arbitrary
+// value types and float priorities.
+//
+// The reasoning behind using floats for the priorities vs. ints or interfaces
+// was larger flexibility without sacrificing too much performance or code
+// complexity.
+//
+// If you would like to use a min-priority queue, simply negate the priorities.
+//
+// Internally the queue is based on the standard heap package working on a
+// sortable version of the block based stack.
+package prque
+
+import (
+	"container/heap"
+)
+
+// Priority queue data structure.
+type Prque struct {
+	cont *sstack
+}
+
+// Creates a new priority queue.
+func New() *Prque {
+	return &Prque{newSstack()}
+}
+
+// Pushes a value with a given priority into the queue, expanding if necessary.
+func (p *Prque) Push(data interface{}, priority float32) {
+	heap.Push(p.cont, &item{data, priority})
+}
+
+// Pops the value with the greates priority off the stack and returns it.
+// Currently no shrinking is done.
+func (p *Prque) Pop() (interface{}, float32) {
+	item := heap.Pop(p.cont).(*item)
+	return item.value, item.priority
+}
+
+// Pops only the item from the queue, dropping the associated priority value.
+func (p *Prque) PopItem() interface{} {
+	return heap.Pop(p.cont).(*item).value
+}
+
+// Checks whether the priority queue is empty.
+func (p *Prque) Empty() bool {
+	return p.cont.Len() == 0
+}
+
+// Returns the number of element in the priority queue.
+func (p *Prque) Size() int {
+	return p.cont.Len()
+}
+
+// Clears the contents of the priority queue.
+func (p *Prque) Reset() {
+	p.cont.Reset()
+}
diff --git a/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/prque_test.go b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/prque_test.go
new file mode 100644
index 000000000..811c53c73
--- /dev/null
+++ b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/prque_test.go
@@ -0,0 +1,110 @@
+// CookieJar - A contestant's algorithm toolbox
+// Copyright (c) 2013 Peter Szilagyi. All rights reserved.
+//
+// CookieJar is dual licensed: you can redistribute it and/or modify it under
+// the terms of the GNU General Public License as published by the Free Software
+// Foundation, either version 3 of the License, or (at your option) any later
+// version.
+//
+// The toolbox is distributed in the hope that it will be useful, but WITHOUT
+// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
+// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
+// more details.
+//
+// Alternatively, the CookieJar toolbox may be used in accordance with the terms
+// and conditions contained in a signed written agreement between you and the
+// author(s).
+
+package prque
+
+import (
+	"math/rand"
+	"testing"
+)
+
+func TestPrque(t *testing.T) {
+	// Generate a batch of random data and a specific priority order
+	size := 16 * blockSize
+	prio := rand.Perm(size)
+	data := make([]int, size)
+	for i := 0; i < size; i++ {
+		data[i] = rand.Int()
+	}
+	queue := New()
+	for rep := 0; rep < 2; rep++ {
+		// Fill a priority queue with the above data
+		for i := 0; i < size; i++ {
+			queue.Push(data[i], float32(prio[i]))
+			if queue.Size() != i+1 {
+				t.Errorf("queue size mismatch: have %v, want %v.", queue.Size(), i+1)
+			}
+		}
+		// Create a map the values to the priorities for easier verification
+		dict := make(map[float32]int)
+		for i := 0; i < size; i++ {
+			dict[float32(prio[i])] = data[i]
+		}
+		// Pop out the elements in priority order and verify them
+		prevPrio := float32(size + 1)
+		for !queue.Empty() {
+			val, prio := queue.Pop()
+			if prio > prevPrio {
+				t.Errorf("invalid priority order: %v after %v.", prio, prevPrio)
+			}
+			prevPrio = prio
+			if val != dict[prio] {
+				t.Errorf("push/pop mismatch: have %v, want %v.", val, dict[prio])
+			}
+			delete(dict, prio)
+		}
+	}
+}
+
+func TestReset(t *testing.T) {
+	// Fill the queue with some random data
+	size := 16 * blockSize
+	queue := New()
+	for i := 0; i < size; i++ {
+		queue.Push(rand.Int(), rand.Float32())
+	}
+	// Reset and ensure it's empty
+	queue.Reset()
+	if !queue.Empty() {
+		t.Errorf("priority queue not empty after reset: %v", queue)
+	}
+}
+
+func BenchmarkPush(b *testing.B) {
+	// Create some initial data
+	data := make([]int, b.N)
+	prio := make([]float32, b.N)
+	for i := 0; i < len(data); i++ {
+		data[i] = rand.Int()
+		prio[i] = rand.Float32()
+	}
+	// Execute the benchmark
+	b.ResetTimer()
+	queue := New()
+	for i := 0; i < len(data); i++ {
+		queue.Push(data[i], prio[i])
+	}
+}
+
+func BenchmarkPop(b *testing.B) {
+	// Create some initial data
+	data := make([]int, b.N)
+	prio := make([]float32, b.N)
+	for i := 0; i < len(data); i++ {
+		data[i] = rand.Int()
+		prio[i] = rand.Float32()
+	}
+	queue := New()
+	for i := 0; i < len(data); i++ {
+		queue.Push(data[i], prio[i])
+	}
+	// Execute the benchmark
+	b.ResetTimer()
+	for !queue.Empty() {
+		queue.Pop()
+	}
+}
diff --git a/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/sstack.go b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/sstack.go
new file mode 100644
index 000000000..55375a091
--- /dev/null
+++ b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/sstack.go
@@ -0,0 +1,103 @@
+// CookieJar - A contestant's algorithm toolbox
+// Copyright (c) 2013 Peter Szilagyi. All rights reserved.
+//
+// CookieJar is dual licensed: you can redistribute it and/or modify it under
+// the terms of the GNU General Public License as published by the Free Software
+// Foundation, either version 3 of the License, or (at your option) any later
+// version.
+//
+// The toolbox is distributed in the hope that it will be useful, but WITHOUT
+// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
+// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
+// more details.
+//
+// Alternatively, the CookieJar toolbox may be used in accordance with the terms
+// and conditions contained in a signed written agreement between you and the
+// author(s).
+
+package prque
+
+// The size of a block of data
+const blockSize = 4096
+
+// A prioritized item in the sorted stack.
+type item struct {
+	value    interface{}
+	priority float32
+}
+
+// Internal sortable stack data structure. Implements the Push and Pop ops for
+// the stack (heap) functionality and the Len, Less and Swap methods for the
+// sortability requirements of the heaps.
+type sstack struct {
+	size     int
+	capacity int
+	offset   int
+
+	blocks [][]*item
+	active []*item
+}
+
+// Creates a new, empty stack.
+func newSstack() *sstack {
+	result := new(sstack)
+	result.active = make([]*item, blockSize)
+	result.blocks = [][]*item{result.active}
+	result.capacity = blockSize
+	return result
+}
+
+// Pushes a value onto the stack, expanding it if necessary. Required by
+// heap.Interface.
+func (s *sstack) Push(data interface{}) {
+	if s.size == s.capacity {
+		s.active = make([]*item, blockSize)
+		s.blocks = append(s.blocks, s.active)
+		s.capacity += blockSize
+		s.offset = 0
+	} else if s.offset == blockSize {
+		s.active = s.blocks[s.size/blockSize]
+		s.offset = 0
+	}
+	s.active[s.offset] = data.(*item)
+	s.offset++
+	s.size++
+}
+
+// Pops a value off the stack and returns it. Currently no shrinking is done.
+// Required by heap.Interface.
+func (s *sstack) Pop() (res interface{}) {
+	s.size--
+	s.offset--
+	if s.offset < 0 {
+		s.offset = blockSize - 1
+		s.active = s.blocks[s.size/blockSize]
+	}
+	res, s.active[s.offset] = s.active[s.offset], nil
+	return
+}
+
+// Returns the length of the stack. Required by sort.Interface.
+func (s *sstack) Len() int {
+	return s.size
+}
+
+// Compares the priority of two elements of the stack (higher is first).
+// Required by sort.Interface.
+func (s *sstack) Less(i, j int) bool {
+	return s.blocks[i/blockSize][i%blockSize].priority > s.blocks[j/blockSize][j%blockSize].priority
+}
+
+// Swapts two elements in the stack. Required by sort.Interface.
+func (s *sstack) Swap(i, j int) {
+	ib, io, jb, jo := i/blockSize, i%blockSize, j/blockSize, j%blockSize
+	s.blocks[ib][io], s.blocks[jb][jo] = s.blocks[jb][jo], s.blocks[ib][io]
+}
+
+// Resets the stack, effectively clearing its contents.
+func (s *sstack) Reset() {
+	s.size = 0
+	s.offset = 0
+	s.active = s.blocks[0]
+	s.capacity = blockSize
+}
diff --git a/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/sstack_test.go b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/sstack_test.go
new file mode 100644
index 000000000..7bdc08bf5
--- /dev/null
+++ b/Godeps/_workspace/src/gopkg.in/karalabe/cookiejar.v2/collections/prque/sstack_test.go
@@ -0,0 +1,93 @@
+// CookieJar - A contestant's algorithm toolbox
+// Copyright (c) 2013 Peter Szilagyi. All rights reserved.
+//
+// CookieJar is dual licensed: you can redistribute it and/or modify it under
+// the terms of the GNU General Public License as published by the Free Software
+// Foundation, either version 3 of the License, or (at your option) any later
+// version.
+//
+// The toolbox is distributed in the hope that it will be useful, but WITHOUT
+// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
+// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
+// more details.
+//
+// Alternatively, the CookieJar toolbox may be used in accordance with the terms
+// and conditions contained in a signed written agreement between you and the
+// author(s).
+
+package prque
+
+import (
+	"math/rand"
+	"sort"
+	"testing"
+)
+
+func TestSstack(t *testing.T) {
+	// Create some initial data
+	size := 16 * blockSize
+	data := make([]*item, size)
+	for i := 0; i < size; i++ {
+		data[i] = &item{rand.Int(), rand.Float32()}
+	}
+	stack := newSstack()
+	for rep := 0; rep < 2; rep++ {
+		// Push all the data into the stack, pop out every second
+		secs := []*item{}
+		for i := 0; i < size; i++ {
+			stack.Push(data[i])
+			if i%2 == 0 {
+				secs = append(secs, stack.Pop().(*item))
+			}
+		}
+		rest := []*item{}
+		for stack.Len() > 0 {
+			rest = append(rest, stack.Pop().(*item))
+		}
+		// Make sure the contents of the resulting slices are ok
+		for i := 0; i < size; i++ {
+			if i%2 == 0 && data[i] != secs[i/2] {
+				t.Errorf("push/pop mismatch: have %v, want %v.", secs[i/2], data[i])
+			}
+			if i%2 == 1 && data[i] != rest[len(rest)-i/2-1] {
+				t.Errorf("push/pop mismatch: have %v, want %v.", rest[len(rest)-i/2-1], data[i])
+			}
+		}
+	}
+}
+
+func TestSstackSort(t *testing.T) {
+	// Create some initial data
+	size := 16 * blockSize
+	data := make([]*item, size)
+	for i := 0; i < size; i++ {
+		data[i] = &item{rand.Int(), float32(i)}
+	}
+	// Push all the data into the stack
+	stack := newSstack()
+	for _, val := range data {
+		stack.Push(val)
+	}
+	// Sort and pop the stack contents (should reverse the order)
+	sort.Sort(stack)
+	for _, val := range data {
+		out := stack.Pop()
+		if out != val {
+			t.Errorf("push/pop mismatch after sort: have %v, want %v.", out, val)
+		}
+	}
+}
+
+func TestSstackReset(t *testing.T) {
+	// Push some stuff onto the stack
+	size := 16 * blockSize
+	stack := newSstack()
+	for i := 0; i < size; i++ {
+		stack.Push(&item{i, float32(i)})
+	}
+	// Clear and verify
+	stack.Reset()
+	if stack.Len() != 0 {
+		t.Errorf("stack not empty after reset: %v", stack)
+	}
+}
diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 15f4cb0a3..608acf499 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -11,11 +11,10 @@ import (
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
-	"gopkg.in/fatih/set.v0"
 )
 
 const (
-	maxBlockFetch    = 256              // Amount of max blocks to be fetched per chunk
+	maxBlockFetch    = 128              // Amount of max blocks to be fetched per chunk
 	peerCountTimeout = 12 * time.Second // Amount of time it takes for the peer handler to ignore minDesiredPeerCount
 	hashTtl          = 20 * time.Second // The amount of time it takes for a hash request to time out
 )
@@ -80,7 +79,7 @@ type Downloader struct {
 
 func New(hasBlock hashCheckFn, getBlock getBlockFn) *Downloader {
 	downloader := &Downloader{
-		queue:     newqueue(),
+		queue:     newQueue(),
 		peers:     make(peers),
 		hasBlock:  hasBlock,
 		getBlock:  getBlock,
@@ -93,7 +92,7 @@ func New(hasBlock hashCheckFn, getBlock getBlockFn) *Downloader {
 }
 
 func (d *Downloader) Stats() (current int, max int) {
-	return d.queue.blockHashes.Size(), d.queue.fetchPool.Size() + d.queue.hashPool.Size()
+	return d.queue.Size()
 }
 
 func (d *Downloader) RegisterPeer(id string, hash common.Hash, getHashes hashFetcherFn, getBlocks blockFetcherFn) error {
@@ -111,7 +110,7 @@ func (d *Downloader) RegisterPeer(id string, hash common.Hash, getHashes hashFet
 	return nil
 }
 
-// UnregisterPeer unregister's a peer. This will prevent any action from the specified peer.
+// UnregisterPeer unregisters a peer. This will prevent any action from the specified peer.
 func (d *Downloader) UnregisterPeer(id string) {
 	d.mu.Lock()
 	defer d.mu.Unlock()
@@ -121,20 +120,20 @@ func (d *Downloader) UnregisterPeer(id string) {
 	delete(d.peers, id)
 }
 
-// SynchroniseWithPeer will select the peer and use it for synchronising. If an empty string is given
-// it will use the best peer possible and synchronise if it's TD is higher than our own. If any of the
+// SynchroniseWithPeer will select the peer and use it for synchronizing. If an empty string is given
+// it will use the best peer possible and synchronize if it's TD is higher than our own. If any of the
 // checks fail an error will be returned. This method is synchronous
 func (d *Downloader) Synchronise(id string, hash common.Hash) error {
 	// Make sure it's doing neither. Once done we can restart the
 	// downloading process if the TD is higher. For now just get on
-	// with whatever is going on. This prevents unecessary switching.
+	// with whatever is going on. This prevents unnecessary switching.
 	if d.isBusy() {
 		return errBusy
 	}
 
-	// When a synchronisation attempt is made while the queue stil
+	// When a synchronization attempt is made while the queue still
 	// contains items we abort the sync attempt
-	if d.queue.size() > 0 {
+	if done, pend := d.queue.Size(); done+pend > 0 {
 		return errPendingQueue
 	}
 
@@ -157,56 +156,23 @@ func (d *Downloader) Synchronise(id string, hash common.Hash) error {
 // are processed. If the block count reaches zero and done is called
 // we reset the queue for the next batch of incoming hashes and blocks.
 func (d *Downloader) Done() {
-	d.queue.mu.Lock()
-	defer d.queue.mu.Unlock()
-
-	if len(d.queue.blocks) == 0 {
-		d.queue.resetNoTS()
-	}
+	d.queue.Done()
 }
 
 // TakeBlocks takes blocks from the queue and yields them to the blockTaker handler
 // it's possible it yields no blocks
 func (d *Downloader) TakeBlocks() types.Blocks {
-	d.queue.mu.Lock()
-	defer d.queue.mu.Unlock()
-
-	var blocks types.Blocks
-	if len(d.queue.blocks) > 0 {
-		// Make sure the parent hash is known
-		if d.queue.blocks[0] != nil && !d.hasBlock(d.queue.blocks[0].ParentHash()) {
-			return nil
-		}
-
-		for _, block := range d.queue.blocks {
-			if block == nil {
-				break
-			}
-
-			blocks = append(blocks, block)
-		}
-		d.queue.blockOffset += len(blocks)
-		// delete the blocks from the slice and let them be garbage collected
-		// without this slice trick the blocks would stay in memory until nil
-		// would be assigned to d.queue.blocks
-		copy(d.queue.blocks, d.queue.blocks[len(blocks):])
-		for k, n := len(d.queue.blocks)-len(blocks), len(d.queue.blocks); k < n; k++ {
-			d.queue.blocks[k] = nil
-		}
-		d.queue.blocks = d.queue.blocks[:len(d.queue.blocks)-len(blocks)]
-
-		//d.queue.blocks = d.queue.blocks[len(blocks):]
-		if len(d.queue.blocks) == 0 {
-			d.queue.blocks = nil
-		}
-
+	// Check that there are blocks available and its parents are known
+	head := d.queue.GetHeadBlock()
+	if head == nil || !d.hasBlock(head.ParentHash()) {
+		return nil
 	}
-
-	return blocks
+	// Retrieve a full batch of blocks
+	return d.queue.TakeBlocks(head)
 }
 
 func (d *Downloader) Has(hash common.Hash) bool {
-	return d.queue.has(hash)
+	return d.queue.Has(hash)
 }
 
 func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool) (err error) {
@@ -214,7 +180,7 @@ func (d *Downloader) getFromPeer(p *peer, hash common.Hash, ignoreInitial bool)
 	defer func() {
 		// reset on error
 		if err != nil {
-			d.queue.reset()
+			d.queue.Reset()
 		}
 	}()
 
@@ -244,7 +210,7 @@ func (d *Downloader) startFetchingHashes(p *peer, h common.Hash, ignoreInitial b
 	atomic.StoreInt32(&d.fetchingHashes, 1)
 	defer atomic.StoreInt32(&d.fetchingHashes, 0)
 
-	if d.queue.has(h) {
+	if d.queue.Has(h) { // TODO: Is this possible? Shouldn't queue be empty for startFetchingHashes to be even called?
 		return errAlreadyInPool
 	}
 
@@ -256,7 +222,7 @@ func (d *Downloader) startFetchingHashes(p *peer, h common.Hash, ignoreInitial b
 	// In such circumstances we don't need to download the block so don't add it to the queue.
 	if !ignoreInitial {
 		// Add the hash to the queue first
-		d.queue.hashPool.Add(h)
+		d.queue.Insert([]common.Hash{h})
 	}
 	// Get the first batch of hashes
 	p.getHashes(h)
@@ -273,7 +239,7 @@ out:
 	for {
 		select {
 		case hashPack := <-d.hashCh:
-			// make sure the active peer is giving us the hashes
+			// Make sure the active peer is giving us the hashes
 			if hashPack.peerId != activePeer.id {
 				glog.V(logger.Debug).Infof("Received hashes from incorrect peer(%s)\n", hashPack.peerId)
 				break
@@ -281,43 +247,37 @@ out:
 
 			failureResponseTimer.Reset(hashTtl)
 
-			var (
-				hashes = hashPack.hashes
-				done   bool // determines whether we're done fetching hashes (i.e. common hash found)
-			)
-			hashSet := set.New()
-			for _, hash = range hashes {
-				if d.hasBlock(hash) || d.queue.blockHashes.Has(hash) {
-					glog.V(logger.Debug).Infof("Found common hash %x\n", hash[:4])
+			// Make sure the peer actually gave something valid
+			if len(hashPack.hashes) == 0 {
+				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", activePeer.id)
+				d.queue.Reset()
 
+				return errEmptyHashSet
+			}
+			// Determine if we're done fetching hashes (queue up all pending), and continue if not done
+			done, index := false, 0
+			for index, hash = range hashPack.hashes {
+				if d.hasBlock(hash) || d.queue.GetBlock(hash) != nil {
+					glog.V(logger.Debug).Infof("Found common hash %x\n", hash[:4])
+					hashPack.hashes = hashPack.hashes[:index]
 					done = true
 					break
 				}
-
-				hashSet.Add(hash)
 			}
-			d.queue.put(hashSet)
-
-			// Add hashes to the chunk set
-			if len(hashes) == 0 { // Make sure the peer actually gave you something valid
-				glog.V(logger.Debug).Infof("Peer (%s) responded with empty hash set\n", activePeer.id)
-				d.queue.reset()
+			d.queue.Insert(hashPack.hashes)
 
-				return errEmptyHashSet
-			} else if !done { // Check if we're done fetching
-				// Get the next set of hashes
+			if !done {
 				activePeer.getHashes(hash)
-			} else { // we're done
-				// The offset of the queue is determined by the highest known block
-				var offset int
-				if block := d.getBlock(hash); block != nil {
-					offset = int(block.NumberU64() + 1)
-				}
-				// allocate proper size for the queueue
-				d.queue.alloc(offset, d.queue.hashPool.Size())
-
-				break out
+				continue
 			}
+			// We're done, allocate the download cache and proceed pulling the blocks
+			offset := 0
+			if block := d.getBlock(hash); block != nil {
+				offset = int(block.NumberU64() + 1)
+			}
+			d.queue.Alloc(offset)
+			break out
+
 		case <-failureResponseTimer.C:
 			glog.V(logger.Debug).Infof("Peer (%s) didn't respond in time for hash request\n", p.id)
 
@@ -326,7 +286,7 @@ out:
 			// already fetched hash list. This can't guarantee 100% correctness but does
 			// a fair job. This is always either correct or false incorrect.
 			for id, peer := range d.peers {
-				if d.queue.hashPool.Has(peer.recentHash) && !attemptedPeers[id] {
+				if d.queue.Has(peer.recentHash) && !attemptedPeers[id] {
 					p = peer
 					break
 				}
@@ -335,7 +295,7 @@ out:
 			// if all peers have been tried, abort the process entirely or if the hash is
 			// the zero hash.
 			if p == nil || (hash == common.Hash{}) {
-				d.queue.reset()
+				d.queue.Reset()
 				return errTimeout
 			}
 
@@ -346,13 +306,14 @@ out:
 			glog.V(logger.Debug).Infof("Hash fetching switched to new peer(%s)\n", p.id)
 		}
 	}
-	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.hashPool.Size(), time.Since(start))
+	glog.V(logger.Detail).Infof("Downloaded hashes (%d) in %v\n", d.queue.Pending(), time.Since(start))
 
 	return nil
 }
 
 func (d *Downloader) startFetchingBlocks(p *peer) error {
-	glog.V(logger.Detail).Infoln("Downloading", d.queue.hashPool.Size(), "block(s)")
+	glog.V(logger.Detail).Infoln("Downloading", d.queue.Pending(), "block(s)")
+
 	atomic.StoreInt32(&d.downloadingBlocks, 1)
 	defer atomic.StoreInt32(&d.downloadingBlocks, 0)
 	// Defer the peer reset. This will empty the peer requested set
@@ -362,7 +323,7 @@ func (d *Downloader) startFetchingBlocks(p *peer) error {
 
 	start := time.Now()
 
-	// default ticker for re-fetching blocks everynow and then
+	// default ticker for re-fetching blocks every now and then
 	ticker := time.NewTicker(20 * time.Millisecond)
 out:
 	for {
@@ -371,7 +332,7 @@ out:
 			// If the peer was previously banned and failed to deliver it's pack
 			// in a reasonable time frame, ignore it's message.
 			if d.peers[blockPack.peerId] != nil {
-				err := d.queue.deliver(blockPack.peerId, blockPack.blocks)
+				err := d.queue.Deliver(blockPack.peerId, blockPack.blocks)
 				if err != nil {
 					glog.V(logger.Debug).Infof("deliver failed for peer %s: %v\n", blockPack.peerId, err)
 					// FIXME d.UnregisterPeer(blockPack.peerId)
@@ -385,46 +346,49 @@ out:
 				d.peers.setState(blockPack.peerId, idleState)
 			}
 		case <-ticker.C:
-			// after removing bad peers make sure we actually have suffucient peer left to keep downlading
+			// after removing bad peers make sure we actually have sufficient peer left to keep downloading
 			if len(d.peers) == 0 {
-				d.queue.reset()
+				d.queue.Reset()
 
 				return errNoPeers
 			}
 
 			// If there are unrequested hashes left start fetching
 			// from the available peers.
-			if d.queue.hashPool.Size() > 0 {
+			if d.queue.Pending() > 0 {
+				// Throttle the download if block cache is full and waiting processing
+				if d.queue.Throttle() {
+					continue
+				}
+
 				availablePeers := d.peers.get(idleState)
 				for _, peer := range availablePeers {
 					// Get a possible chunk. If nil is returned no chunk
 					// could be returned due to no hashes available.
-					chunk := d.queue.get(peer, maxBlockFetch)
-					if chunk == nil {
+					request := d.queue.Reserve(peer, maxBlockFetch)
+					if request == nil {
 						continue
 					}
-
 					// XXX make fetch blocking.
 					// Fetch the chunk and check for error. If the peer was somehow
 					// already fetching a chunk due to a bug, it will be returned to
 					// the queue
-					if err := peer.fetch(chunk); err != nil {
+					if err := peer.fetch(request); err != nil {
 						// log for tracing
 						glog.V(logger.Debug).Infof("peer %s received double work (state = %v)\n", peer.id, peer.state)
-						d.queue.put(chunk.hashes)
+						d.queue.Cancel(request)
 					}
 				}
-
 				// make sure that we have peers available for fetching. If all peers have been tried
 				// and all failed throw an error
-				if len(d.queue.fetching) == 0 {
-					d.queue.reset()
+				if d.queue.InFlight() == 0 {
+					d.queue.Reset()
 
-					return fmt.Errorf("%v peers avaialable = %d. total peers = %d. hashes needed = %d", errPeersUnavailable, len(availablePeers), len(d.peers), d.queue.hashPool.Size())
+					return fmt.Errorf("%v peers avaialable = %d. total peers = %d. hashes needed = %d", errPeersUnavailable, len(availablePeers), len(d.peers), d.queue.Pending())
 				}
 
-			} else if len(d.queue.fetching) == 0 {
-				// When there are no more queue and no more `fetching`. We can
+			} else if d.queue.InFlight() == 0 {
+				// When there are no more queue and no more in flight, We can
 				// safely assume we're done. Another part of the process will  check
 				// for parent errors and will re-request anything that's missing
 				break out
@@ -434,27 +398,13 @@ out:
 				// that badly or poorly behave are removed from the peer set (not banned).
 				// Bad peers are excluded from the available peer set and therefor won't be
 				// reused. XXX We could re-introduce peers after X time.
-				d.queue.mu.Lock()
-				var badPeers []string
-				for pid, chunk := range d.queue.fetching {
-					if time.Since(chunk.itime) > blockTtl {
-						badPeers = append(badPeers, pid)
-						// remove peer as good peer from peer list
-						// FIXME d.UnregisterPeer(pid)
-					}
-				}
-				d.queue.mu.Unlock()
-
+				badPeers := d.queue.Expire(blockTtl)
 				for _, pid := range badPeers {
-					// A nil chunk is delivered so that the chunk's hashes are given
-					// back to the queue objects. When hashes are put back in the queue
-					// other (decent) peers can pick them up.
 					// XXX We could make use of a reputation system here ranking peers
 					// in their performance
 					// 1) Time for them to respond;
 					// 2) Measure their speed;
 					// 3) Amount and availability.
-					d.queue.deliver(pid, nil)
 					if peer := d.peers[pid]; peer != nil {
 						peer.demote()
 						peer.reset()
@@ -486,7 +436,7 @@ func (d *Downloader) AddHashes(id string, hashes []common.Hash) error {
 
 	if glog.V(logger.Detail) && len(hashes) != 0 {
 		from, to := hashes[0], hashes[len(hashes)-1]
-		glog.Infof("adding %d (T=%d) hashes [ %x / %x ] from: %s\n", len(hashes), d.queue.hashPool.Size(), from[:4], to[:4], id)
+		glog.Infof("adding %d (T=%d) hashes [ %x / %x ] from: %s\n", len(hashes), d.queue.Pending(), from[:4], to[:4], id)
 	}
 
 	d.hashCh <- hashPack{id, hashes}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 872ea02eb..11834d788 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -128,7 +128,7 @@ func TestDownload(t *testing.T) {
 		t.Error("download error", err)
 	}
 
-	inqueue := len(tester.downloader.queue.blocks)
+	inqueue := len(tester.downloader.queue.blockCache)
 	if inqueue != targetBlocks {
 		t.Error("expected", targetBlocks, "have", inqueue)
 	}
@@ -151,7 +151,7 @@ func TestMissing(t *testing.T) {
 		t.Error("download error", err)
 	}
 
-	inqueue := len(tester.downloader.queue.blocks)
+	inqueue := len(tester.downloader.queue.blockCache)
 	if inqueue != targetBlocks {
 		t.Error("expected", targetBlocks, "have", inqueue)
 	}
diff --git a/eth/downloader/peer.go b/eth/downloader/peer.go
index 91977f592..45ec1cbfd 100644
--- a/eth/downloader/peer.go
+++ b/eth/downloader/peer.go
@@ -78,7 +78,7 @@ func newPeer(id string, hash common.Hash, getHashes hashFetcherFn, getBlocks blo
 }
 
 // fetch a chunk using the peer
-func (p *peer) fetch(chunk *chunk) error {
+func (p *peer) fetch(request *fetchRequest) error {
 	p.mu.Lock()
 	defer p.mu.Unlock()
 
@@ -88,13 +88,12 @@ func (p *peer) fetch(chunk *chunk) error {
 
 	// set working state
 	p.state = workingState
-	// convert the set to a fetchable slice
-	hashes, i := make([]common.Hash, chunk.hashes.Size()), 0
-	chunk.hashes.Each(func(v interface{}) bool {
-		hashes[i] = v.(common.Hash)
-		i++
-		return true
-	})
+
+	// Convert the hash set to a fetchable slice
+	hashes := make([]common.Hash, 0, len(request.Hashes))
+	for hash, _ := range request.Hashes {
+		hashes = append(hashes, hash)
+	}
 	p.getBlocks(hashes)
 
 	return nil
diff --git a/eth/downloader/queue.go b/eth/downloader/queue.go
index 1b63a5ffb..eae567052 100644
--- a/eth/downloader/queue.go
+++ b/eth/downloader/queue.go
@@ -1,201 +1,349 @@
 package downloader
 
 import (
+	"errors"
 	"fmt"
-	"math"
 	"sync"
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core/types"
-	"gopkg.in/fatih/set.v0"
+	"gopkg.in/karalabe/cookiejar.v2/collections/prque"
 )
 
+const (
+	blockCacheLimit = 4096 // Maximum number of blocks to cache before throttling the download
+)
+
+// fetchRequest is a currently running block retrieval operation.
+type fetchRequest struct {
+	Peer   *peer               // Peer to which the request was sent
+	Hashes map[common.Hash]int // Requested hashes with their insertion index (priority)
+	Time   time.Time           // Time when the request was made
+}
+
 // queue represents hashes that are either need fetching or are being fetched
 type queue struct {
-	hashPool    *set.Set
-	fetchPool   *set.Set
-	blockHashes *set.Set
+	hashPool    map[common.Hash]int // Pending hashes, mapping to their insertion index (priority)
+	hashQueue   *prque.Prque        // Priority queue of the block hashes to fetch
+	hashCounter int                 // Counter indexing the added hashes to ensure retrieval order
+
+	pendPool  map[string]*fetchRequest // Currently pending block retrieval operations
+	pendCount int                      // Number of pending block fetches (to throttle the download)
 
-	mu       sync.Mutex
-	fetching map[string]*chunk
+	blockPool   map[common.Hash]int // Hash-set of the downloaded data blocks, mapping to cache indexes
+	blockCache  []*types.Block      // Downloaded but not yet delivered blocks
+	blockOffset int                 // Offset of the first cached block in the block-chain
 
-	blockOffset int
-	blocks      []*types.Block
+	lock sync.RWMutex
 }
 
-func newqueue() *queue {
+// newQueue creates a new download queue for scheduling block retrieval.
+func newQueue() *queue {
 	return &queue{
-		hashPool:    set.New(),
-		fetchPool:   set.New(),
-		blockHashes: set.New(),
-		fetching:    make(map[string]*chunk),
+		hashPool:  make(map[common.Hash]int),
+		hashQueue: prque.New(),
+		pendPool:  make(map[string]*fetchRequest),
+		blockPool: make(map[common.Hash]int),
 	}
 }
 
-func (c *queue) reset() {
-	c.mu.Lock()
-	defer c.mu.Unlock()
+// Reset clears out the queue contents.
+func (q *queue) Reset() {
+	q.lock.Lock()
+	defer q.lock.Unlock()
 
-	c.resetNoTS()
+	q.hashPool = make(map[common.Hash]int)
+	q.hashQueue.Reset()
+	q.hashCounter = 0
+
+	q.pendPool = make(map[string]*fetchRequest)
+	q.pendCount = 0
+
+	q.blockPool = make(map[common.Hash]int)
+	q.blockOffset = 0
+	q.blockCache = nil
 }
-func (c *queue) resetNoTS() {
-	c.blockOffset = 0
-	c.hashPool.Clear()
-	c.fetchPool.Clear()
-	c.blockHashes.Clear()
-	c.blocks = nil
-	c.fetching = make(map[string]*chunk)
+
+// Done checks if all the downloads have been retrieved, wiping the queue.
+func (q *queue) Done() {
+	q.lock.Lock()
+	defer q.lock.Unlock()
+
+	if len(q.blockCache) == 0 {
+		q.Reset()
+	}
 }
 
-func (c *queue) size() int {
-	return c.hashPool.Size() + c.blockHashes.Size() + c.fetchPool.Size()
+// Size retrieves the number of hashes in the queue, returning separately for
+// pending and already downloaded.
+func (q *queue) Size() (int, int) {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
+
+	return len(q.hashPool), len(q.blockPool)
 }
 
-// reserve a `max` set of hashes for `p` peer.
-func (c *queue) get(p *peer, max int) *chunk {
-	c.mu.Lock()
-	defer c.mu.Unlock()
+// Pending retrieves the number of hashes pending for retrieval.
+func (q *queue) Pending() int {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
 
-	// return nothing if the pool has been depleted
-	if c.hashPool.Size() == 0 {
-		return nil
-	}
+	return q.hashQueue.Size()
+}
 
-	limit := int(math.Min(float64(max), float64(c.hashPool.Size())))
-	// Create a new set of hashes
-	hashes, i := set.New(), 0
-	c.hashPool.Each(func(v interface{}) bool {
-		// break on limit
-		if i == limit {
-			return false
-		}
-		// skip any hashes that have previously been requested from the peer
-		if p.ignored.Has(v) {
-			return true
-		}
+// InFlight retrieves the number of fetch requests currently in flight.
+func (q *queue) InFlight() int {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
 
-		hashes.Add(v)
-		i++
+	return len(q.pendPool)
+}
 
+// Throttle checks if the download should be throttled (active block fetches
+// exceed block cache).
+func (q *queue) Throttle() bool {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
+
+	return q.pendCount >= len(q.blockCache)-len(q.blockPool)
+}
+
+// Has checks if a hash is within the download queue or not.
+func (q *queue) Has(hash common.Hash) bool {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
+
+	if _, ok := q.hashPool[hash]; ok {
+		return true
+	}
+	if _, ok := q.blockPool[hash]; ok {
 		return true
-	})
-	// if no hashes can be requested return a nil chunk
-	if hashes.Size() == 0 {
-		return nil
 	}
+	return false
+}
 
-	// remove the fetchable hashes from hash pool
-	c.hashPool.Separate(hashes)
-	c.fetchPool.Merge(hashes)
+// Insert adds a set of hashes for the download queue for scheduling.
+func (q *queue) Insert(hashes []common.Hash) {
+	q.lock.Lock()
+	defer q.lock.Unlock()
 
-	// Create a new chunk for the seperated hashes. The time is being used
-	// to reset the chunk (timeout)
-	chunk := &chunk{p, hashes, time.Now()}
-	// register as 'fetching' state
-	c.fetching[p.id] = chunk
+	// Insert all the hashes prioritized in the arrival order
+	for i, hash := range hashes {
+		index := q.hashCounter + i
 
-	// create new chunk for peer
-	return chunk
+		q.hashPool[hash] = index
+		q.hashQueue.Push(hash, float32(index)) // Highest gets schedules first
+	}
+	// Update the hash counter for the next batch of inserts
+	q.hashCounter += len(hashes)
 }
 
-func (c *queue) has(hash common.Hash) bool {
-	return c.hashPool.Has(hash) || c.fetchPool.Has(hash) || c.blockHashes.Has(hash)
+// GetHeadBlock retrieves the first block from the cache, or nil if it hasn't
+// been downloaded yet (or simply non existent).
+func (q *queue) GetHeadBlock() *types.Block {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
+
+	if len(q.blockCache) == 0 {
+		return nil
+	}
+	return q.blockCache[0]
 }
 
-func (c *queue) getBlock(hash common.Hash) *types.Block {
-	c.mu.Lock()
-	defer c.mu.Unlock()
+// GetBlock retrieves a downloaded block, or nil if non-existent.
+func (q *queue) GetBlock(hash common.Hash) *types.Block {
+	q.lock.RLock()
+	defer q.lock.RUnlock()
 
-	if !c.blockHashes.Has(hash) {
+	// Short circuit if the block hasn't been downloaded yet
+	index, ok := q.blockPool[hash]
+	if !ok {
 		return nil
 	}
-
-	for _, block := range c.blocks {
-		if block.Hash() == hash {
-			return block
-		}
+	// Return the block if it's still available in the cache
+	if q.blockOffset <= index && index < q.blockOffset+len(q.blockCache) {
+		return q.blockCache[index-q.blockOffset]
 	}
 	return nil
 }
 
-// deliver delivers a chunk to the queue that was requested of the peer
-func (c *queue) deliver(id string, blocks []*types.Block) (err error) {
-	c.mu.Lock()
-	defer c.mu.Unlock()
-
-	chunk := c.fetching[id]
-	// If the chunk was never requested simply ignore it
-	if chunk != nil {
-		delete(c.fetching, id)
-		// check the length of the returned blocks. If the length of blocks is 0
-		// we'll assume the peer doesn't know about the chain.
-		if len(blocks) == 0 {
-			// So we can ignore the blocks we didn't know about
-			chunk.peer.ignored.Merge(chunk.hashes)
-		}
+// TakeBlocks retrieves and permanently removes a batch of blocks from the cache.
+// The head parameter is required to prevent a race condition where concurrent
+// takes may fail parent verifications.
+func (q *queue) TakeBlocks(head *types.Block) types.Blocks {
+	q.lock.Lock()
+	defer q.lock.Unlock()
 
-		// Add the blocks
-		for i, block := range blocks {
-			// See (1) for future limitation
-			n := int(block.NumberU64()) - c.blockOffset
-			if n > len(c.blocks) || n < 0 {
-				// set the error and set the blocks which could be processed
-				// abort the rest of the blocks (FIXME this could be improved)
-				err = fmt.Errorf("received block which overflow (N=%v O=%v)", block.Number(), c.blockOffset)
-				blocks = blocks[:i]
-				break
-			}
-			c.blocks[n] = block
+	// Short circuit if the head block's different
+	if len(q.blockCache) == 0 || q.blockCache[0] != head {
+		return nil
+	}
+	// Otherwise accumulate all available blocks
+	var blocks types.Blocks
+	for _, block := range q.blockCache {
+		if block == nil {
+			break
 		}
-		// seperate the blocks and the hashes
-		blockHashes := chunk.fetchedHashes(blocks)
-		// merge block hashes
-		c.blockHashes.Merge(blockHashes)
-		// Add back whatever couldn't be delivered
-		c.hashPool.Merge(chunk.hashes)
-		// Remove the hashes from the fetch pool
-		c.fetchPool.Separate(chunk.hashes)
+		blocks = append(blocks, block)
+		delete(q.blockPool, block.Hash())
+	}
+	// Delete the blocks from the slice and let them be garbage collected
+	// without this slice trick the blocks would stay in memory until nil
+	// would be assigned to q.blocks
+	copy(q.blockCache, q.blockCache[len(blocks):])
+	for k, n := len(q.blockCache)-len(blocks), len(q.blockCache); k < n; k++ {
+		q.blockCache[k] = nil
 	}
+	q.blockOffset += len(blocks)
 
-	return
+	return blocks
 }
 
-func (c *queue) alloc(offset, size int) {
-	c.mu.Lock()
-	defer c.mu.Unlock()
+// Reserve reserves a set of hashes for the given peer, skipping any previously
+// failed download.
+func (q *queue) Reserve(p *peer, max int) *fetchRequest {
+	q.lock.Lock()
+	defer q.lock.Unlock()
 
-	if c.blockOffset < offset {
-		c.blockOffset = offset
+	// Short circuit if the pool has been depleted
+	if q.hashQueue.Empty() {
+		return nil
 	}
-
-	// (1) XXX at some point we could limit allocation to memory and use the disk
-	// to store future blocks.
-	if len(c.blocks) < size {
-		c.blocks = append(c.blocks, make([]*types.Block, size)...)
+	// Retrieve a batch of hashes, skipping previously failed ones
+	send := make(map[common.Hash]int)
+	skip := make(map[common.Hash]int)
+
+	for len(send) < max && !q.hashQueue.Empty() {
+		hash, priority := q.hashQueue.Pop()
+		if p.ignored.Has(hash) {
+			skip[hash.(common.Hash)] = int(priority)
+		} else {
+			send[hash.(common.Hash)] = int(priority)
+		}
+	}
+	// Merge all the skipped hashes back
+	for hash, index := range skip {
+		q.hashQueue.Push(hash, float32(index))
+	}
+	// Assemble and return the block download request
+	if len(send) == 0 {
+		return nil
 	}
+	request := &fetchRequest{
+		Peer:   p,
+		Hashes: send,
+		Time:   time.Now(),
+	}
+	q.pendPool[p.id] = request
+	q.pendCount += len(request.Hashes)
+
+	return request
 }
 
-// puts puts sets of hashes on to the queue for fetching
-func (c *queue) put(hashes *set.Set) {
-	c.mu.Lock()
-	defer c.mu.Unlock()
+// Cancel aborts a fetch request, returning all pending hashes to the queue.
+func (q *queue) Cancel(request *fetchRequest) {
+	q.lock.Lock()
+	defer q.lock.Unlock()
 
-	c.hashPool.Merge(hashes)
+	for hash, index := range request.Hashes {
+		q.hashQueue.Push(hash, float32(index))
+	}
+	delete(q.pendPool, request.Peer.id)
+	q.pendCount -= len(request.Hashes)
 }
 
-type chunk struct {
-	peer   *peer
-	hashes *set.Set
-	itime  time.Time
+// Expire checks for in flight requests that exceeded a timeout allowance,
+// canceling them and returning the responsible peers for penalization.
+func (q *queue) Expire(timeout time.Duration) []string {
+	q.lock.Lock()
+	defer q.lock.Unlock()
+
+	// Iterate over the expired requests and return each to the queue
+	peers := []string{}
+	for id, request := range q.pendPool {
+		if time.Since(request.Time) > timeout {
+			for hash, index := range request.Hashes {
+				q.hashQueue.Push(hash, float32(index))
+			}
+			q.pendCount -= len(request.Hashes)
+			peers = append(peers, id)
+		}
+	}
+	// Remove the expired requests from the pending pool
+	for _, id := range peers {
+		delete(q.pendPool, id)
+	}
+	return peers
 }
 
-func (ch *chunk) fetchedHashes(blocks []*types.Block) *set.Set {
-	fhashes := set.New()
+// Deliver injects a block retrieval response into the download queue.
+func (q *queue) Deliver(id string, blocks []*types.Block) (err error) {
+	q.lock.Lock()
+	defer q.lock.Unlock()
+
+	// Short circuit if the blocks were never requested
+	request := q.pendPool[id]
+	if request == nil {
+		return errors.New("no fetches pending")
+	}
+	delete(q.pendPool, id)
+
+	// Mark all the hashes in the request as non-pending
+	q.pendCount -= len(request.Hashes)
+
+	// If no blocks were retrieved, mark them as unavailable for the origin peer
+	if len(blocks) == 0 {
+		for hash, _ := range request.Hashes {
+			request.Peer.ignored.Add(hash)
+		}
+	}
+	// Iterate over the downloaded blocks and add each of them
+	errs := make([]error, 0)
 	for _, block := range blocks {
-		fhashes.Add(block.Hash())
+		// Skip any blocks that fall outside the cache range
+		index := int(block.NumberU64()) - q.blockOffset
+		if index >= len(q.blockCache) || index < 0 {
+			//fmt.Printf("block cache overflown (N=%v O=%v, C=%v)", block.Number(), q.blockOffset, len(q.blockCache))
+			continue
+		}
+		// Skip any blocks that were not requested
+		hash := block.Hash()
+		if _, ok := request.Hashes[hash]; !ok {
+			errs = append(errs, fmt.Errorf("non-requested block %v", hash))
+			continue
+		}
+		// Otherwise merge the block and mark the hash block
+		q.blockCache[index] = block
+
+		delete(request.Hashes, hash)
+		delete(q.hashPool, hash)
+		q.blockPool[hash] = int(block.NumberU64())
 	}
-	ch.hashes.Separate(fhashes)
+	// Return all failed fetches to the queue
+	for hash, index := range request.Hashes {
+		q.hashQueue.Push(hash, float32(index))
+	}
+	if len(errs) != 0 {
+		return fmt.Errorf("multiple failures: %v", errs)
+	}
+	return nil
+}
 
-	return fhashes
+// Alloc ensures that the block cache is the correct size, given a starting
+// offset, and a memory cap.
+func (q *queue) Alloc(offset int) {
+	q.lock.Lock()
+	defer q.lock.Unlock()
+
+	if q.blockOffset < offset {
+		q.blockOffset = offset
+	}
+	size := len(q.hashPool)
+	if size > blockCacheLimit {
+		size = blockCacheLimit
+	}
+	if len(q.blockCache) < size {
+		q.blockCache = append(q.blockCache, make([]*types.Block, size-len(q.blockCache))...)
+	}
 }
diff --git a/eth/downloader/queue_test.go b/eth/downloader/queue_test.go
index b163bd9c7..b1f3591f3 100644
--- a/eth/downloader/queue_test.go
+++ b/eth/downloader/queue_test.go
@@ -32,31 +32,30 @@ func createBlocksFromHashSet(hashes *set.Set) []*types.Block {
 }
 
 func TestChunking(t *testing.T) {
-	queue := newqueue()
+	queue := newQueue()
 	peer1 := newPeer("peer1", common.Hash{}, nil, nil)
 	peer2 := newPeer("peer2", common.Hash{}, nil, nil)
 
 	// 99 + 1 (1 == known genesis hash)
 	hashes := createHashes(0, 99)
-	hashSet := createHashSet(hashes)
-	queue.put(hashSet)
+	queue.Insert(hashes)
 
-	chunk1 := queue.get(peer1, 99)
+	chunk1 := queue.Reserve(peer1, 99)
 	if chunk1 == nil {
 		t.Errorf("chunk1 is nil")
 		t.FailNow()
 	}
-	chunk2 := queue.get(peer2, 99)
+	chunk2 := queue.Reserve(peer2, 99)
 	if chunk2 == nil {
 		t.Errorf("chunk2 is nil")
 		t.FailNow()
 	}
 
-	if chunk1.hashes.Size() != 99 {
-		t.Error("expected chunk1 hashes to be 99, got", chunk1.hashes.Size())
+	if len(chunk1.Hashes) != 99 {
+		t.Error("expected chunk1 hashes to be 99, got", len(chunk1.Hashes))
 	}
 
-	if chunk2.hashes.Size() != 1 {
-		t.Error("expected chunk1 hashes to be 1, got", chunk2.hashes.Size())
+	if len(chunk2.Hashes) != 1 {
+		t.Error("expected chunk1 hashes to be 1, got", len(chunk2.Hashes))
 	}
 }
