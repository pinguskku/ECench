commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
commit 81801ccc2b5444ebcf05bf1cf1562fc7a7c2b93e
Author: atsushi-ishibashi <atsushi.ishibashi@finatext.com>
Date:   Thu Feb 7 18:44:45 2019 +0900

    core/state: more memory efficient preimage allocation (#16663)

diff --git a/core/state/statedb.go b/core/state/statedb.go
index 2230b10ef..8ad25a582 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -502,7 +502,7 @@ func (self *StateDB) Copy() *StateDB {
 		refund:            self.refund,
 		logs:              make(map[common.Hash][]*types.Log, len(self.logs)),
 		logSize:           self.logSize,
-		preimages:         make(map[common.Hash][]byte),
+		preimages:         make(map[common.Hash][]byte, len(self.preimages)),
 		journal:           newJournal(),
 	}
 	// Copy the dirty states, logs, and preimages
diff --git a/core/state/statedb_test.go b/core/state/statedb_test.go
index cbd5bc75e..69392d972 100644
--- a/core/state/statedb_test.go
+++ b/core/state/statedb_test.go
@@ -276,6 +276,15 @@ func newTestAction(addr common.Address, r *rand.Rand) testAction {
 			},
 			args: make([]int64, 1),
 		},
+		{
+			name: "AddPreimage",
+			fn: func(a testAction, s *StateDB) {
+				preimage := []byte{1}
+				hash := common.BytesToHash(preimage)
+				s.AddPreimage(hash, preimage)
+			},
+			args: make([]int64, 1),
+		},
 	}
 	action := actions[r.Intn(len(actions))]
 	var nameargs []string
