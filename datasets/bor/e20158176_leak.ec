commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
commit e20158176d2061ff95cdf022aa7113aa7c47a98e
Author: Felix Lange <fjl@twurst.com>
Date:   Tue May 16 20:56:02 2017 +0200

    les: fix goroutine leak in execQueue (#14480)
    
    execQueue used an atomic counter to track whether the queue had been
    closed, but the checking the counter didn't happen because the queue was
    blocked on its channel.
    
    Fix it by using a condition variable instead of sync/atomic. I tried an
    implementation based on channels first, but it was hard to make it
    reliable.
    
    quit now waits for the queue loop to exit.

diff --git a/les/execqueue.go b/les/execqueue.go
index ac779003b..614721bf0 100644
--- a/les/execqueue.go
+++ b/les/execqueue.go
@@ -16,56 +16,82 @@
 
 package les
 
-import (
-	"sync/atomic"
-)
+import "sync"
 
-// ExecQueue implements a queue that executes function calls in a single thread,
+// execQueue implements a queue that executes function calls in a single thread,
 // in the same order as they have been queued.
 type execQueue struct {
-	chn                 chan func()
-	cnt, stop, capacity int32
+	mu        sync.Mutex
+	cond      *sync.Cond
+	funcs     []func()
+	closeWait chan struct{}
 }
 
-// NewExecQueue creates a new execution queue.
-func newExecQueue(capacity int32) *execQueue {
-	q := &execQueue{
-		chn:      make(chan func(), capacity),
-		capacity: capacity,
-	}
+// newExecQueue creates a new execution queue.
+func newExecQueue(capacity int) *execQueue {
+	q := &execQueue{funcs: make([]func(), 0, capacity)}
+	q.cond = sync.NewCond(&q.mu)
 	go q.loop()
 	return q
 }
 
 func (q *execQueue) loop() {
-	for f := range q.chn {
-		atomic.AddInt32(&q.cnt, -1)
-		if atomic.LoadInt32(&q.stop) != 0 {
-			return
-		}
+	for f := q.waitNext(false); f != nil; f = q.waitNext(true) {
 		f()
 	}
+	close(q.closeWait)
 }
 
-// CanQueue returns true if more  function calls can be added to the execution queue.
+func (q *execQueue) waitNext(drop bool) (f func()) {
+	q.mu.Lock()
+	if drop {
+		// Remove the function that just executed. We do this here instead of when
+		// dequeuing so len(q.funcs) includes the function that is running.
+		q.funcs = append(q.funcs[:0], q.funcs[1:]...)
+	}
+	for !q.isClosed() {
+		if len(q.funcs) > 0 {
+			f = q.funcs[0]
+			break
+		}
+		q.cond.Wait()
+	}
+	q.mu.Unlock()
+	return f
+}
+
+func (q *execQueue) isClosed() bool {
+	return q.closeWait != nil
+}
+
+// canQueue returns true if more function calls can be added to the execution queue.
 func (q *execQueue) canQueue() bool {
-	return atomic.LoadInt32(&q.stop) == 0 && atomic.LoadInt32(&q.cnt) < q.capacity
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	q.mu.Unlock()
+	return ok
 }
 
-// Queue adds a function call to the execution queue. Returns true if successful.
+// queue adds a function call to the execution queue. Returns true if successful.
 func (q *execQueue) queue(f func()) bool {
-	if atomic.LoadInt32(&q.stop) != 0 {
-		return false
+	q.mu.Lock()
+	ok := !q.isClosed() && len(q.funcs) < cap(q.funcs)
+	if ok {
+		q.funcs = append(q.funcs, f)
+		q.cond.Signal()
 	}
-	if atomic.AddInt32(&q.cnt, 1) > q.capacity {
-		atomic.AddInt32(&q.cnt, -1)
-		return false
-	}
-	q.chn <- f
-	return true
+	q.mu.Unlock()
+	return ok
 }
 
-// Stop stops the exec queue.
+// quit stops the exec queue.
+// quit waits for the current execution to finish before returning.
 func (q *execQueue) quit() {
-	atomic.StoreInt32(&q.stop, 1)
+	q.mu.Lock()
+	if !q.isClosed() {
+		q.closeWait = make(chan struct{})
+		q.cond.Signal()
+	}
+	q.mu.Unlock()
+	<-q.closeWait
 }
diff --git a/les/execqueue_test.go b/les/execqueue_test.go
new file mode 100644
index 000000000..cd45b03f2
--- /dev/null
+++ b/les/execqueue_test.go
@@ -0,0 +1,62 @@
+// Copyright 2017 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package les
+
+import (
+	"testing"
+)
+
+func TestExecQueue(t *testing.T) {
+	var (
+		N        = 10000
+		q        = newExecQueue(N)
+		counter  int
+		execd    = make(chan int)
+		testexit = make(chan struct{})
+	)
+	defer q.quit()
+	defer close(testexit)
+
+	check := func(state string, wantOK bool) {
+		c := counter
+		counter++
+		qf := func() {
+			select {
+			case execd <- c:
+			case <-testexit:
+			}
+		}
+		if q.canQueue() != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+		if q.queue(qf) != wantOK {
+			t.Fatalf("canQueue() == %t for %s", !wantOK, state)
+		}
+	}
+
+	for i := 0; i < N; i++ {
+		check("queue below cap", true)
+	}
+	check("full queue", false)
+	for i := 0; i < N; i++ {
+		if c := <-execd; c != i {
+			t.Fatal("execution out of order")
+		}
+	}
+	q.quit()
+	check("closed queue", false)
+}
