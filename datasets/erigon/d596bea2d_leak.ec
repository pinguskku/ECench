commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
commit d596bea2d501d20b92e0fd4baa8bba682157dfa7
Author: Elad <theman@elad.im>
Date:   Wed Feb 13 14:15:03 2019 +0700

    swarm: fix uptime gauge update goroutine leak by introducing cleanup functions (#19040)

diff --git a/swarm/swarm.go b/swarm/swarm.go
index 705fc4397..5b0e5f177 100644
--- a/swarm/swarm.go
+++ b/swarm/swarm.go
@@ -79,7 +79,7 @@ type Swarm struct {
 	swap              *swap.Swap
 	stateStore        *state.DBStore
 	accountingMetrics *protocols.AccountingMetrics
-	startTime         time.Time
+	cleanupFuncs      []func() error
 
 	tracerClose io.Closer
 }
@@ -106,9 +106,10 @@ func NewSwarm(config *api.Config, mockStore *mock.NodeStore) (self *Swarm, err e
 	}
 
 	self = &Swarm{
-		config:     config,
-		backend:    backend,
-		privateKey: config.ShiftPrivateKey(),
+		config:       config,
+		backend:      backend,
+		privateKey:   config.ShiftPrivateKey(),
+		cleanupFuncs: []func() error{},
 	}
 	log.Debug("Setting up Swarm service components")
 
@@ -344,7 +345,7 @@ Start is called when the stack is started
 */
 // implements the node.Service interface
 func (self *Swarm) Start(srv *p2p.Server) error {
-	self.startTime = time.Now()
+	startTime := time.Now()
 
 	self.tracerClose = tracing.Closer
 
@@ -396,26 +397,28 @@ func (self *Swarm) Start(srv *p2p.Server) error {
 		}()
 	}
 
-	self.periodicallyUpdateGauges()
+	doneC := make(chan struct{})
 
-	startCounter.Inc(1)
-	self.streamer.Start(srv)
-	return nil
-}
+	self.cleanupFuncs = append(self.cleanupFuncs, func() error {
+		close(doneC)
+		return nil
+	})
 
-func (self *Swarm) periodicallyUpdateGauges() {
-	ticker := time.NewTicker(updateGaugesPeriod)
-
-	go func() {
-		for range ticker.C {
-			self.updateGauges()
+	go func(time.Time) {
+		for {
+			select {
+			case <-time.After(updateGaugesPeriod):
+				uptimeGauge.Update(time.Since(startTime).Nanoseconds())
+				requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+			case <-doneC:
+				return
+			}
 		}
-	}()
-}
+	}(startTime)
 
-func (self *Swarm) updateGauges() {
-	uptimeGauge.Update(time.Since(self.startTime).Nanoseconds())
-	requestsCacheGauge.Update(int64(self.netStore.RequestsCacheLen()))
+	startCounter.Inc(1)
+	self.streamer.Start(srv)
+	return nil
 }
 
 // implements the node.Service interface
@@ -452,6 +455,14 @@ func (self *Swarm) Stop() error {
 	if self.stateStore != nil {
 		self.stateStore.Close()
 	}
+
+	for _, cleanF := range self.cleanupFuncs {
+		err = cleanF()
+		if err != nil {
+			log.Error("encountered an error while running cleanup function", "err", err)
+			break
+		}
+	}
 	return err
 }
 
