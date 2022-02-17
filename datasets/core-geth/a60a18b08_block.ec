commit a60a18b080197cad836f18f9d093bba3bcb6cef8
Author: Viktor Trón <viktor.tron@gmail.com>
Date:   Tue Mar 3 00:43:12 2015 +0700

    - fix peer disconnect by adding severity function to errs
    - improve logging
    - suicide -> removeChain
    - improved status BlocksInPool calculation

diff --git a/blockpool/blockpool.go b/blockpool/blockpool.go
index 0126d734c..5da671ec2 100644
--- a/blockpool/blockpool.go
+++ b/blockpool/blockpool.go
@@ -149,6 +149,15 @@ func New(
 	}
 }
 
+func severity(code int) ethlogger.LogLevel {
+	switch code {
+	case ErrUnrequestedBlock:
+		return ethlogger.WarnLevel
+	default:
+		return ethlogger.ErrorLevel
+	}
+}
+
 // allows restart
 func (self *BlockPool) Start() {
 	self.lock.Lock()
@@ -169,6 +178,7 @@ func (self *BlockPool) Start() {
 		errors: &errs.Errors{
 			Package: "Blockpool",
 			Errors:  errorToString,
+			Level:   severity,
 		},
 		peers:  make(map[string]*peer),
 		status: self.status,
@@ -363,6 +373,8 @@ LOOP:
 			// check if known block connecting the downloaded chain to our blockchain
 			plog.DebugDetailf("AddBlockHashes: peer <%s> (head: %s) found block %s in the blockchain", peerId, hex(bestpeer.currentBlockHash), hex(hash))
 			if len(nodes) == 1 {
+				plog.DebugDetailf("AddBlockHashes: singleton section pushed to blockchain peer <%s> (head: %s) found block %s in the blockchain", peerId, hex(bestpeer.currentBlockHash), hex(hash))
+
 				// create new section if needed and push it to the blockchain
 				sec = self.newSection(nodes)
 				sec.addSectionToBlockChain(bestpeer)
@@ -379,6 +391,8 @@ LOOP:
 					and td together with blockBy are recorded on the node
 				*/
 				if len(nodes) == 0 && child != nil {
+					plog.DebugDetailf("AddBlockHashes: child section [%s] pushed to blockchain peer <%s> (head: %s) found block %s in the blockchain", sectionhex(child), peerId, hex(bestpeer.currentBlockHash), hex(hash))
+
 					child.addSectionToBlockChain(bestpeer)
 				}
 			}
@@ -446,10 +460,12 @@ LOOP:
 	*/
 	sec = self.linkSections(nodes, parent, child)
 
-	self.status.lock.Lock()
-	self.status.values.BlockHashes += len(nodes)
-	self.status.lock.Unlock()
-	plog.DebugDetailf("AddBlockHashes: peer <%s> (head: %s): section [%s] created", peerId, hex(bestpeer.currentBlockHash), sectionhex(sec))
+	if sec != nil {
+		self.status.lock.Lock()
+		self.status.values.BlockHashes += len(nodes)
+		self.status.lock.Unlock()
+		plog.DebugDetailf("AddBlockHashes: peer <%s> (head: %s): section [%s] created", peerId, hex(bestpeer.currentBlockHash), sectionhex(sec))
+	}
 
 	self.chainLock.Unlock()
 
@@ -549,6 +565,7 @@ func (self *BlockPool) AddBlock(block *types.Block, peerId string) {
 			self.status.lock.Unlock()
 		} else {
 			plog.DebugDetailf("AddBlock: head block %s for peer <%s> (head: %s) already known", hex(hash), peerId, hex(sender.currentBlockHash))
+			sender.currentBlockC <- block
 		}
 	} else {
 
@@ -644,11 +661,15 @@ LOOP:
 		  we need to relink both complete and incomplete sections
 		  the latter could have been blockHashesRequestsComplete before being delinked from its parent
 		*/
-		if parent == nil && sec.bottom.block != nil {
-			if entry := self.get(sec.bottom.block.ParentHash()); entry != nil {
-				parent = entry.section
-				plog.DebugDetailf("activateChain: [%s]-[%s] relink", sectionhex(parent), sectionhex(sec))
-				link(parent, sec)
+		if parent == nil {
+			if sec.bottom.block != nil {
+				if entry := self.get(sec.bottom.block.ParentHash()); entry != nil {
+					parent = entry.section
+					plog.DebugDetailf("activateChain: [%s]-[%s] link", sectionhex(parent), sectionhex(sec))
+					link(parent, sec)
+				}
+			} else {
+				plog.DebugDetailf("activateChain: section [%s] activated by peer <%s> has missing root block", sectionhex(sec), p.id)
 			}
 		}
 		sec = parent
@@ -704,9 +725,15 @@ func (self *BlockPool) remove(sec *section) {
 	// delete node entries from pool index under pool lock
 	self.lock.Lock()
 	defer self.lock.Unlock()
+
 	for _, node := range sec.nodes {
 		delete(self.pool, string(node.hash))
 	}
+	if sec.initialised && sec.poolRootIndex != 0 {
+		self.status.lock.Lock()
+		self.status.values.BlocksInPool -= len(sec.nodes) - sec.missing
+		self.status.lock.Unlock()
+	}
 }
 
 func (self *BlockPool) getHashSlice() (s [][]byte) {
diff --git a/blockpool/peers.go b/blockpool/peers.go
index 5f1b2017c..576d6e41d 100644
--- a/blockpool/peers.go
+++ b/blockpool/peers.go
@@ -503,7 +503,7 @@ LOOP:
 
 		// quitting on timeout
 		case <-self.suicide:
-			self.peerError(self.bp.peers.errors.New(ErrInsufficientChainInfo, "timed out without providing block hashes or head block", currentBlockHash))
+			self.peerError(self.bp.peers.errors.New(ErrInsufficientChainInfo, "timed out without providing block hashes or head block %x", currentBlockHash))
 
 			self.bp.status.lock.Lock()
 			self.bp.status.badPeers[self.id]++
diff --git a/blockpool/section.go b/blockpool/section.go
index 48ea15d31..03c4f5cc6 100644
--- a/blockpool/section.go
+++ b/blockpool/section.go
@@ -138,7 +138,7 @@ func (self *section) addSectionToBlockChain(p *peer) {
 			plog.Warnf("penalise peers %v (hash), %v (block)", node.hashBy, node.blockBy)
 
 			// or invalid block and the entire chain needs to be removed
-			self.removeInvalidChain()
+			self.removeChain()
 		} else {
 			// if all blocks inserted in this section
 			// then need to try to insert blocks in child section
@@ -235,16 +235,14 @@ LOOP:
 
 		// timebomb - if section is not complete in time, nuke the entire chain
 		case <-self.suicideTimer:
-			self.suicide()
+			self.removeChain()
 			plog.Debugf("[%s] timeout. (%v total attempts): missing %v/%v/%v...suicide", sectionhex(self), self.blocksRequests, self.missing, self.lastMissing, self.depth)
 			self.suicideTimer = nil
+			break LOOP
 
 		// closing suicideC triggers section suicide: removes section nodes from pool and terminates section process
 		case <-self.suicideC:
-			plog.DebugDetailf("[%s] suicide", sectionhex(self))
-			self.unlink()
-			self.bp.remove(self)
-			plog.DebugDetailf("[%s] done", sectionhex(self))
+			plog.DebugDetailf("[%s] quit", sectionhex(self))
 			break LOOP
 
 		// alarm for checking blocks in the section
@@ -283,7 +281,7 @@ LOOP:
 				checking = false
 				break
 			}
-			plog.DebugDetailf("[%s] section proc step %v: missing %v/%v/%v", sectionhex(self), self.step, self.missing, self.lastMissing, self.depth)
+			// plog.DebugDetailf("[%s] section proc step %v: missing %v/%v/%v", sectionhex(self), self.step, self.missing, self.lastMissing, self.depth)
 			if !checking {
 				self.step = 0
 				self.missing = 0
@@ -522,7 +520,7 @@ func (self *section) checkRound() {
 				// too many idle rounds
 				if self.idle >= self.bp.Config.BlocksRequestMaxIdleRounds {
 					plog.DebugDetailf("[%s] block requests had %v idle rounds (%v total attempts): missing %v/%v/%v\ngiving up...", sectionhex(self), self.idle, self.blocksRequests, self.missing, self.lastMissing, self.depth)
-					self.suicide()
+					self.removeChain()
 				}
 			} else {
 				self.idle = 0
@@ -602,10 +600,12 @@ func (self *BlockPool) linkSections(nodes []*node, parent, child *section) (sec
 		link(parent, sec)
 		link(sec, child)
 	} else {
-		// now this can only happen if we allow response to hash request to include <from> hash
-		// in this case we just link parent and child (without needing root block of child section)
-		plog.Debugf("[%s]->[%s] connecting known sections", sectionhex(parent), sectionhex(child))
-		link(parent, child)
+		if parent != nil && child != nil {
+			// now this can only happen if we allow response to hash request to include <from> hash
+			// in this case we just link parent and child (without needing root block of child section)
+			plog.Debugf("[%s]->[%s] connecting known sections", sectionhex(parent), sectionhex(child))
+			link(parent, child)
+		}
 	}
 	return
 }
@@ -614,6 +614,7 @@ func (self *section) activate(p *peer) {
 	self.bp.wg.Add(1)
 	select {
 	case <-self.offC:
+		plog.DebugDetailf("[%s] completed section process. cannot activate for peer <%s>", sectionhex(self), p.id)
 		self.bp.wg.Done()
 	case self.controlC <- p:
 		plog.DebugDetailf("[%s] activate section process for peer <%s>", sectionhex(self), p.id)
@@ -625,22 +626,10 @@ func (self *section) deactivate() {
 	self.controlC <- nil
 }
 
-func (self *section) suicide() {
-	select {
-	case <-self.suicideC:
-		return
-	default:
-	}
-	close(self.suicideC)
-}
-
 // removes this section exacly
 func (self *section) remove() {
 	select {
 	case <-self.offC:
-		// section is complete, no process
-		self.unlink()
-		self.bp.remove(self)
 		close(self.suicideC)
 		plog.DebugDetailf("[%s] remove: suicide", sectionhex(self))
 	case <-self.suicideC:
@@ -649,21 +638,23 @@ func (self *section) remove() {
 		plog.DebugDetailf("[%s] remove: suicide", sectionhex(self))
 		close(self.suicideC)
 	}
+	self.unlink()
+	self.bp.remove(self)
 	plog.DebugDetailf("[%s] removed section.", sectionhex(self))
 
 }
 
 // remove a section and all its descendents from the pool
-func (self *section) removeInvalidChain() {
+func (self *section) removeChain() {
 	// need to get the child before removeSection delinks the section
 	self.bp.chainLock.RLock()
 	child := self.child
 	self.bp.chainLock.RUnlock()
 
-	plog.DebugDetailf("[%s] remove invalid chain", sectionhex(self))
+	plog.DebugDetailf("[%s] remove chain", sectionhex(self))
 	self.remove()
 	if child != nil {
-		child.removeInvalidChain()
+		child.removeChain()
 	}
 }
 
diff --git a/blockpool/status.go b/blockpool/status.go
index 0dd874232..4529c77fe 100644
--- a/blockpool/status.go
+++ b/blockpool/status.go
@@ -51,7 +51,6 @@ type Status struct {
 func (self *BlockPool) Status() *Status {
 	self.status.lock.Lock()
 	defer self.status.lock.Unlock()
-	self.status.values.BlockHashesInPool = len(self.pool)
 	self.status.values.ActivePeers = len(self.status.activePeers)
 	self.status.values.BestPeers = len(self.status.bestPeers)
 	self.status.values.BadPeers = len(self.status.badPeers)
