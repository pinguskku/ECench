commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
commit a355b401db8a0299f4be98320bbc7db53ef86975
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Jun 1 00:14:59 2017 +0300

    ethstats: reduce ethstats traffic by trottling reports

diff --git a/ethstats/ethstats.go b/ethstats/ethstats.go
index ad77cd1e8..333c975c9 100644
--- a/ethstats/ethstats.go
+++ b/ethstats/ethstats.go
@@ -31,6 +31,7 @@ import (
 	"time"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/mclock"
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
@@ -119,7 +120,7 @@ func (s *Service) Stop() error {
 // loop keeps trying to connect to the netstats server, reporting chain events
 // until termination.
 func (s *Service) loop() {
-	// Subscribe tso chain events to execute updates on
+	// Subscribe to chain events to execute updates on
 	var emux *event.TypeMux
 	if s.eth != nil {
 		emux = s.eth.EventMux()
@@ -132,6 +133,46 @@ func (s *Service) loop() {
 	txSub := emux.Subscribe(core.TxPreEvent{})
 	defer txSub.Unsubscribe()
 
+	// Start a goroutine that exhausts the subsciptions to avoid events piling up
+	var (
+		quitCh = make(chan struct{})
+		headCh = make(chan *types.Block, 1)
+		txCh   = make(chan struct{}, 1)
+	)
+	go func() {
+		var lastTx mclock.AbsTime
+
+		for {
+			select {
+			// Notify of chain head events, but drop if too frequent
+			case head, ok := <-headSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				select {
+				case headCh <- head.Data.(core.ChainHeadEvent).Block:
+				default:
+				}
+
+			// Notify of new transaction events, but drop if too frequent
+			case _, ok := <-txSub.Chan():
+				if !ok { // node stopped
+					close(quitCh)
+					return
+				}
+				if time.Duration(mclock.Now()-lastTx) < time.Second {
+					continue
+				}
+				lastTx = mclock.Now()
+
+				select {
+				case txCh <- struct{}{}:
+				default:
+				}
+			}
+		}
+	}()
 	// Loop reporting until termination
 	for {
 		// Resolve the URL, defaulting to TLS, but falling back to none too
@@ -151,7 +192,7 @@ func (s *Service) loop() {
 			if conf, err = websocket.NewConfig(url, "http://localhost/"); err != nil {
 				continue
 			}
-			conf.Dialer = &net.Dialer{Timeout: 3 * time.Second}
+			conf.Dialer = &net.Dialer{Timeout: 5 * time.Second}
 			if conn, err = websocket.DialConfig(conf); err == nil {
 				break
 			}
@@ -181,6 +222,10 @@ func (s *Service) loop() {
 
 		for err == nil {
 			select {
+			case <-quitCh:
+				conn.Close()
+				return
+
 			case <-fullReport.C:
 				if err = s.report(conn); err != nil {
 					log.Warn("Full stats report failed", "err", err)
@@ -189,30 +234,14 @@ func (s *Service) loop() {
 				if err = s.reportHistory(conn, list); err != nil {
 					log.Warn("Requested history report failed", "err", err)
 				}
-			case head, ok := <-headSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				if err = s.reportBlock(conn, head.Data.(core.ChainHeadEvent).Block); err != nil {
+			case head := <-headCh:
+				if err = s.reportBlock(conn, head); err != nil {
 					log.Warn("Block stats report failed", "err", err)
 				}
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Post-block transaction stats report failed", "err", err)
 				}
-			case _, ok := <-txSub.Chan():
-				if !ok { // node stopped
-					conn.Close()
-					return
-				}
-				// Exhaust events to avoid reporting too frequently
-				for exhausted := false; !exhausted; {
-					select {
-					case <-headSub.Chan():
-					default:
-						exhausted = true
-					}
-				}
+			case <-txCh:
 				if err = s.reportPending(conn); err != nil {
 					log.Warn("Transaction stats report failed", "err", err)
 				}
@@ -398,7 +427,7 @@ func (s *Service) reportLatency(conn *websocket.Conn) error {
 	select {
 	case <-s.pongCh:
 		// Pong delivered, report the latency
-	case <-time.After(3 * time.Second):
+	case <-time.After(5 * time.Second):
 		// Ping timeout, abort
 		return errors.New("ping timed out")
 	}
