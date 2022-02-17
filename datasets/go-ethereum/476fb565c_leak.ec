commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
commit 476fb565cecb483f7506f4dceb438d506464194d
Author: Martin Holst Swende <martin@swende.se>
Date:   Fri Nov 5 16:17:13 2021 +0100

    miner, consensus/clique: avoid memory leak during block stasis (#23861)
    
    This PR fixes a problem which arises on clique networks when there is a network stall. Previously, the worker packages were tracked, even if the sealing engine decided not to seal the block (due to clique rules about recent signing). These tracked-but-not-sealed blocks kept building up in memory.
    This PR changes the situation so the sealing engine instead returns an error, and the worker can thus un-track the package.

diff --git a/consensus/clique/clique.go b/consensus/clique/clique.go
index a6a16c84a..38597e152 100644
--- a/consensus/clique/clique.go
+++ b/consensus/clique/clique.go
@@ -600,8 +600,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 	}
 	// For 0-period chains, refuse to seal empty blocks (no reward but would spin sealing)
 	if c.config.Period == 0 && len(block.Transactions()) == 0 {
-		log.Info("Sealing paused, waiting for transactions")
-		return nil
+		return errors.New("sealing paused while waiting for transactions")
 	}
 	// Don't hold the signer fields for the entire sealing procedure
 	c.lock.RLock()
@@ -621,8 +620,7 @@ func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, res
 		if recent == signer {
 			// Signer is among recents, only wait if the current block doesn't shift it out
 			if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
-				log.Info("Signed recently, must wait for others")
-				return nil
+				return errors.New("signed recently, must wait for others")
 			}
 		}
 	}
diff --git a/miner/worker.go b/miner/worker.go
index 4ef2c8c0d..77e868c2b 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -593,6 +593,9 @@ func (w *worker) taskLoop() {
 
 			if err := w.engine.Seal(w.chain, task.block, w.resultCh, stopCh); err != nil {
 				log.Warn("Block sealing failed", "err", err)
+				w.pendingMu.Lock()
+				delete(w.pendingTasks, sealHash)
+				w.pendingMu.Unlock()
 			}
 		case <-w.exitCh:
 			interrupt()
