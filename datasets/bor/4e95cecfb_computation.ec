commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
commit 4e95cecfb999425e40b0c071b9768b1654167fe2
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Oct 14 14:29:04 2014 +0200

    ethlog: improve dispatch concurrency
    
    This also fixes a deadlock in the tests.

diff --git a/ethlog/loggers.go b/ethlog/loggers.go
index b2760534b..34561853a 100644
--- a/ethlog/loggers.go
+++ b/ethlog/loggers.go
@@ -29,20 +29,6 @@ func newPrintfLogMessage(level LogLevel, tag string, format string, v ...interfa
 	return &logMessage{level, true, fmt.Sprintf("[%s] %s", tag, fmt.Sprintf(format, v...))}
 }
 
-func (msg *logMessage) send(logger LogSystem) {
-	if msg.format {
-		logger.Printf(msg.msg)
-	} else {
-		logger.Println(msg.msg)
-	}
-}
-
-var logMessages chan (*logMessage)
-var logSystems []LogSystem
-var quit chan chan error
-var drained chan bool
-var mutex = sync.Mutex{}
-
 type LogLevel uint8
 
 const (
@@ -54,56 +40,80 @@ const (
 	DebugDetailLevel
 )
 
-func dispatch(msg *logMessage) {
-	for _, logSystem := range logSystems {
-		if logSystem.GetLogLevel() >= msg.LogLevel {
-			msg.send(logSystem)
-		}
-	}
+var (
+	mutex      sync.RWMutex // protects logSystems
+	logSystems []LogSystem
+
+	logMessages  = make(chan *logMessage)
+	drainWaitReq = make(chan chan struct{})
+)
+
+func init() {
+	go dispatchLoop()
 }
 
-// log messages are dispatched to log writers
-func start() {
+func dispatchLoop() {
+	var drainWait []chan struct{}
+	dispatchDone := make(chan struct{})
+	pending := 0
 	for {
 		select {
-		case status := <-quit:
-			status <- nil
-			return
 		case msg := <-logMessages:
-			dispatch(msg)
-		default:
-			drained <- true // this blocks until a message is sent to the queue
+			go dispatch(msg, dispatchDone)
+			pending++
+		case waiter := <-drainWaitReq:
+			if pending == 0 {
+				close(waiter)
+			} else {
+				drainWait = append(drainWait, waiter)
+			}
+		case <-dispatchDone:
+			pending--
+			if pending == 0 {
+				for _, c := range drainWait {
+					close(c)
+				}
+				drainWait = nil
+			}
 		}
 	}
 }
 
+func dispatch(msg *logMessage, done chan<- struct{}) {
+	mutex.RLock()
+	for _, sys := range logSystems {
+		if sys.GetLogLevel() >= msg.LogLevel {
+			if msg.format {
+				sys.Printf(msg.msg)
+			} else {
+				sys.Println(msg.msg)
+			}
+		}
+	}
+	mutex.RUnlock()
+	done <- struct{}{}
+}
+
+// send delivers a message to all installed log
+// systems. it doesn't wait for the message to be
+// written.
 func send(msg *logMessage) {
 	logMessages <- msg
-	select {
-	case <-drained:
-	default:
-	}
 }
 
+// Reset removes all registered log systems.
 func Reset() {
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems != nil {
-		status := make(chan error)
-		quit <- status
-		select {
-		case <-drained:
-		default:
-		}
-		<-status
-	}
+	logSystems = nil
+	mutex.Unlock()
 }
 
-// waits until log messages are drained (dispatched to log writers)
+// Flush waits until all current log messages have been dispatched to
+// the active log systems.
 func Flush() {
-	if logSystems != nil {
-		<-drained
-	}
+	waiter := make(chan struct{})
+	drainWaitReq <- waiter
+	<-waiter
 }
 
 type Logger struct {
@@ -115,16 +125,9 @@ func NewLogger(tag string) *Logger {
 }
 
 func AddLogSystem(logSystem LogSystem) {
-	var mutex = &sync.Mutex{}
 	mutex.Lock()
-	defer mutex.Unlock()
-	if logSystems == nil {
-		logMessages = make(chan *logMessage, 10)
-		quit = make(chan chan error, 1)
-		drained = make(chan bool, 1)
-		go start()
-	}
 	logSystems = append(logSystems, logSystem)
+	mutex.Unlock()
 }
 
 func (logger *Logger) sendln(level LogLevel, v ...interface{}) {
